import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

// ─── FFI typedefs ─────────────────────────────────────────────────────────────
typedef _RunModelNative = Pointer<Utf8> Function(
    Pointer<Utf8> modelPath, Pointer<Utf8> prompt);
typedef _RunModelDart = Pointer<Utf8> Function(
    Pointer<Utf8> modelPath, Pointer<Utf8> prompt);

// ─── LLM Service ─────────────────────────────────────────────────────────────
class LLMService {
  static DynamicLibrary? _lib;
  static _RunModelDart?  _runFn;

  static void _ensureLoaded() {
    if (_lib != null) return;
    _lib  = DynamicLibrary.open('libllama_lib.so');
    _runFn = _lib!
        .lookupFunction<_RunModelNative, _RunModelDart>('run_model_path');
  }

  /// Run inference on the given model file with the given prompt.
  /// Always called from a background Isolate via compute().
  Future<String> run(String modelPath, String prompt) async {
    if (!Platform.isAndroid) return 'FFI only supported on Android.';

    // Brief yield so the UI "thinking" state is rendered before blocking
    await Future<void>.delayed(Duration.zero);

    try {
      _ensureLoaded();

      final mpPtr     = modelPath.toNativeUtf8();
      final pPtr      = prompt.toNativeUtf8();
      final resultPtr = _runFn!(mpPtr, pPtr);
      final text      = resultPtr.toDartString();

      malloc.free(mpPtr);
      malloc.free(pPtr);

      return text.isEmpty ? '(No response generated)' : text;
    } catch (e, st) {
      return 'Error: $e\n$st';
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
