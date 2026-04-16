import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

// ─── FFI typedefs ─────────────────────────────────────────────────────────────
typedef _RunModelNative     = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _RunModelDart       = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _ReleaseCacheNative = Void Function();
typedef _ReleaseCacheDart   = void Function();

// ─── Isolate message types ─────────────────────────────────────────────────────
// Only plain Dart objects (no native pointers) cross isolate boundaries.
class _InferRequest {
  final String    modelPath;
  final String    prompt;
  final SendPort  replyTo;
  const _InferRequest(this.modelPath, this.prompt, this.replyTo);
}

class _ReleaseRequest { const _ReleaseRequest(); }

// ─── Long-lived background isolate entry ──────────────────────────────────────
// This function runs ONCE for the lifetime of the app in a dedicated OS thread.
// The native libllama_lib.so is loaded here; the C++ g_model cache persists
// between calls because this isolate never dies.
//
// Why a long-lived isolate instead of Isolate.run()?
//   Isolate.run() spawns + destroys a fresh isolate each call → g_model freed
//   → full model reload on every message (2-18 s lag). A persistent isolate
//   keeps the C++ cache alive across all messages.
//
// Why not the main isolate?
//   FFI blocks the calling thread. On Android, blocking the main thread for
//   > 5 seconds triggers ANR and the OS kills the app.
void _inferenceIsolateMain(SendPort readyPort) {
  final inbox = ReceivePort();

  // Load the native library inside this isolate.
  // FFI works from any Dart isolate on Android.
  late final _RunModelDart       runFn;
  late final _ReleaseCacheDart   releaseFn;

  try {
    final lib = DynamicLibrary.open('libllama_lib.so');
    runFn     = lib.lookupFunction<_RunModelNative, _RunModelDart>('run_model_path');
    releaseFn = lib.lookupFunction<_ReleaseCacheNative, _ReleaseCacheDart>('release_model_cache');
  } catch (e) {
    readyPort.send('ERROR:$e');
    return;
  }

  // Signal main isolate that we are alive and ready to receive requests.
  readyPort.send(inbox.sendPort);

  // ── Message loop (stream-based) ───────────────────────────────────────────
  inbox.listen((msg) {
    if (msg is _InferRequest) {
      String result;
      try {
        final mpPtr     = msg.modelPath.toNativeUtf8();
        final pPtr      = msg.prompt.toNativeUtf8();
        final resultPtr = runFn(mpPtr, pPtr);          // blocks THIS thread only
        result          = resultPtr.toDartString();
        malloc.free(mpPtr);
        malloc.free(pPtr);
        if (result.isEmpty) result = '(No response generated)';
      } catch (e, st) {
        result = 'Error during inference: $e\n$st';
      }
      msg.replyTo.send(result);

    } else if (msg is _ReleaseRequest) {
      try { releaseFn(); } catch (_) {}
    }
    // Any other message type is silently ignored.
  });
}

// ─── LLMService ───────────────────────────────────────────────────────────────
class LLMService {

  // ── Singleton inference isolate ───────────────────────────────────────────
  static Isolate?  _isolate;
  static SendPort? _isolateSendPort;
  static bool      _busy = false;

  /// Ensures the background inference isolate is running.
  /// Safe to call multiple times; does nothing if already initialised.
  /// Call this at app startup to pre-warm the isolate.
  static Future<void> ensureIsolate() async {
    if (_isolate != null && _isolateSendPort != null) return;

    final readyPort = ReceivePort();
    _isolate = await Isolate.spawn(
      _inferenceIsolateMain,
      readyPort.sendPort,
      debugName: 'RamaAI-Inference',
    );

    final first = await readyPort.first;
    if (first is String && first.startsWith('ERROR:')) {
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      throw Exception('Failed to start inference isolate: ${first.substring(6)}');
    }
    _isolateSendPort = first as SendPort;
  }

  // ── Run inference ─────────────────────────────────────────────────────────
  /// Sends [prompt] to the background isolate and waits for the reply.
  /// Never blocks the UI thread. Returns an error string on failure.
  static Future<String> runInference(String modelPath, String prompt) async {
    if (!Platform.isAndroid) return 'FFI only supported on Android.';
    if (_busy) return 'Error: Inference already in progress. Please wait.';

    _busy = true;
    try {
      await ensureIsolate();

      final replyPort = ReceivePort();
      _isolateSendPort!.send(
        _InferRequest(modelPath, prompt, replyPort.sendPort),
      );

      // Await result from background isolate — UI thread is FREE during this.
      final result = await replyPort.first as String;
      replyPort.close();
      return result;

    } catch (e, st) {
      return 'Error: $e\n$st';
    } finally {
      _busy = false;
    }
  }

  // ── Release cached model ──────────────────────────────────────────────────
  /// Tells the background isolate to free the cached C++ model.
  /// Call this when the user switches to a different model file.
  static Future<void> releaseModelCache() async {
    if (_isolateSendPort == null) return;
    _isolateSendPort!.send(const _ReleaseRequest());
  }

  // ── Model file helpers ────────────────────────────────────────────────────

  /// App-private external storage directory for GGUF model files.
  static Future<Directory> get modelsDir async {
    final base = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/RAMA_AI/models');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Absolute path where a named model file will be saved / expected.
  static Future<String> modelSavePath(String filename) async {
    final dir = await modelsDir;
    return '${dir.path}/$filename';
  }

  /// List all .gguf files currently in the models directory, sorted by name.
  static Future<List<File>> listModels() async {
    final dir = await modelsDir;
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.gguf'))
        .toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  }
}