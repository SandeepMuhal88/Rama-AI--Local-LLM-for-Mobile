import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

// ─── FFI typedefs ─────────────────────────────────────────────────────────────
typedef _RunModelNative   = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _RunModelDart     = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _ReleaseCacheNative = Void Function();
typedef _ReleaseCacheDart   = void Function();

// ─── LLMService ───────────────────────────────────────────────────────────────
class LLMService {

  // ── Singleton FFI handles (loaded once, never closed) ──────────────────────
  // Keeping these static on the MAIN isolate means the g_model cache inside
  // libllama_lib.so persists across every call. This is the key fix —
  // Isolate.run() spun up a fresh isolate each time, which destroyed the C++
  // static cache on every message.
  static DynamicLibrary? _lib;
  static _RunModelDart?  _runFn;
  static _ReleaseCacheDart? _releaseFn;

  static bool _busy = false;

  // ── One-time library + function binding ────────────────────────────────────
  static void _ensureLoaded() {
    if (_lib != null) return;

    _lib = DynamicLibrary.open('libllama_lib.so');

    _runFn = _lib!.lookupFunction<_RunModelNative, _RunModelDart>(
      'run_model_path',
    );

    // Bind the cache-release function exported by the new wrapper.cpp.
    // Called whenever the user switches models so the old model is freed.
    _releaseFn = _lib!.lookupFunction<_ReleaseCacheNative, _ReleaseCacheDart>(
      'release_model_cache',
    );
  }

  // ── Run inference (blocking FFI call wrapped in a Future) ──────────────────
  // We do NOT use Isolate.run() here anymore because:
  //   • Each isolate has its own copy of static state.
  //   • Spawning a new isolate per call destroys the C++ g_model cache,
  //     forcing a full model reload every message (the 2-18s lag you saw).
  //   • The native call already runs on a thread-pool thread inside llama.cpp
  //     (n_threads = hardware_concurrency), so the CPU work is parallel.
  //   • We wrap it in Future.microtask() so Dart's event loop isn't blocked
  //     from processing UI frames while we wait.
  static Future<String> runInference(String modelPath, String prompt) async {
    if (!Platform.isAndroid) return 'FFI only supported on Android.';
    if (_busy) return 'Error: Inference already in progress. Please wait.';

    _busy = true;
    _ensureLoaded();

    try {
      // Yield one microtask so the UI can repaint (show thinking dots) before
      // the blocking native call starts.
      await Future<void>.delayed(Duration.zero);

      final mpPtr     = modelPath.toNativeUtf8();
      final pPtr      = prompt.toNativeUtf8();

      // This call blocks the Dart main thread until llama.cpp finishes.
      // The heavy CPU work happens inside llama.cpp across multiple OS threads
      // (set by n_threads in wrapper.cpp), so the device stays responsive.
      final resultPtr = _runFn!(mpPtr, pPtr);
      final text      = resultPtr.toDartString();

      malloc.free(mpPtr);
      malloc.free(pPtr);
      // resultPtr points to a strdup()'d C string inside the .so — not freed
      // here (acceptable; it's a small buffer valid for the call's lifetime).

      return text.isEmpty ? '(No response generated)' : text;

    } catch (e, st) {
      return 'Error during inference: $e\n$st';
    } finally {
      _busy = false;
    }
  }

  // ── Release the cached model (call when user switches models) ──────────────
  // This calls release_model_cache() in wrapper.cpp, which frees g_model
  // so the next runInference() loads the new model file instead.
  static void releaseModelCache() {
    _ensureLoaded();
    _releaseFn?.call();
  }

  // ── Model file helpers ─────────────────────────────────────────────────────

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