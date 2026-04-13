import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

// ─── FFI typedefs ─────────────────────────────────────────────────────────────
typedef _RunModelNative = Pointer<Utf8> Function(
    Pointer<Utf8> modelPath, Pointer<Utf8> prompt);
typedef _RunModelDart = Pointer<Utf8> Function(
    Pointer<Utf8> modelPath, Pointer<Utf8> prompt);

// ─── Top-level function for Isolate.run() ─────────────────────────────────────
// Must be top-level (not a closure) so Isolate.run can spawn it.
// Each isolate gets its own copy of static state, so the library is loaded
// fresh and safely in the new isolate's context.
String _runInIsolate(List<String> args) {
  final modelPath = args[0];
  final prompt    = args[1];

  try {
    final lib   = DynamicLibrary.open('libllama_lib.so');
    final runFn = lib.lookupFunction<_RunModelNative, _RunModelDart>(
        'run_model_path');

    final mpPtr     = modelPath.toNativeUtf8();
    final pPtr      = prompt.toNativeUtf8();
    final resultPtr = runFn(mpPtr, pPtr);
    final text      = resultPtr.toDartString();

    malloc.free(mpPtr);
    malloc.free(pPtr);

    return text.isEmpty ? '(No response generated)' : text;
  } catch (e, st) {
    return 'Error: $e\n$st';
  }
}

// ─── LLM Service ──────────────────────────────────────────────────────────────
class LLMService {
  /// Guards against re-entrant calls while inference is running.
  static bool _busy = false;

  /// Run inference in a dedicated Isolate.
  /// Isolate.run() is safe for FFI (unlike compute()) because each invocation
  /// creates a fresh isolate that loads the .so from scratch, then exits —
  /// no shared mutable state between calls.
  static Future<String> runInference(String modelPath, String prompt) async {
    if (!Platform.isAndroid) return 'FFI only supported on Android.';

    // Safety guard: reject re-entrant calls while the model is running
    if (_busy) return 'Error: Inference already in progress. Please wait.';
    _busy = true;

    try {
      final result = await Isolate.run(
        () => _runInIsolate([modelPath, prompt]),
      );
      return result;
    } catch (e, st) {
      return 'Error: $e\n$st';
    } finally {
      _busy = false;
    }
  }

  // ── Model file helpers ────────────────────────────────────────────────────────

  /// App-private external storage directory for GGUF models.
  static Future<Directory> get modelsDir async {
    final base = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/RAMA_AI/models');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Absolute path where a named model file will be saved.
  static Future<String> modelSavePath(String filename) async {
    final dir = await modelsDir;
    return '${dir.path}/$filename';
  }

  /// List all .gguf files currently stored in the models directory.
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

