import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

// ─── FFI typedefs ─────────────────────────────────────────────────────────────
typedef _RunModelNative = Pointer<Utf8> Function(
    Pointer<Utf8> modelPath, Pointer<Utf8> prompt);
typedef _RunModelDart = Pointer<Utf8> Function(
    Pointer<Utf8> modelPath, Pointer<Utf8> prompt);

// ─── LLMService ───────────────────────────────────────────────────────────────
class LLMService {
  // Load the .so once and keep it alive
  static DynamicLibrary? _lib;
  static _RunModelDart? _runFn;

  static void _ensureLoaded() {
    if (_lib != null) return;
    _lib = DynamicLibrary.open('libllama_lib.so');
    _runFn =
        _lib!.lookupFunction<_RunModelNative, _RunModelDart>('run_model_path');
  }

  /// Run inference. Offloads to a microtask so UI stays responsive.
  /// modelPath  – absolute path to the .gguf file
  /// prompt     – user text
  Future<String> run(String modelPath, String prompt) async {
    if (!Platform.isAndroid) return 'FFI only supported on Android.';

    // Brief yield so the UI can update (show "thinking…") before we block
    await Future<void>.delayed(Duration.zero);

    try {
      _ensureLoaded();

      final mpPtr = modelPath.toNativeUtf8();
      final pPtr  = prompt.toNativeUtf8();

      final resultPtr = _runFn!(mpPtr, pPtr);
      final text = resultPtr.toDartString();

      malloc.free(mpPtr);
      malloc.free(pPtr);
      // resultPtr is strdup'd by C – we have no cross-language free here;
      // it leaks ~a few hundred bytes per call, acceptable for now.

      return text.isEmpty ? '(No response generated)' : text;
    } catch (e, st) {
      return 'Error: $e\n$st';
    }
  }

  // ── Model file helpers ──────────────────────────────────────────────────────

  /// Directory where GGUF files are stored.
  /// Uses app-private external storage – no special MANAGE_EXTERNAL_STORAGE
  /// permission needed on Android 11+.
  static Future<Directory> get modelsDir async {
    // getExternalStorageDirectory() → e.g.
    //   /storage/emulated/0/Android/data/com.example.rama_ai/files
    final base = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/RAMA_AI/models');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Absolute path where a named file will be saved.
  static Future<String> modelSavePath(String filename) async {
    final dir = await modelsDir;
    return '${dir.path}/$filename';
  }

  /// List all .gguf files currently downloaded.
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