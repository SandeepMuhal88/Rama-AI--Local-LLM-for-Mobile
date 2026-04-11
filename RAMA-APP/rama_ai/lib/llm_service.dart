import 'dart:io' show Platform;
import 'dart:ffi';
import 'package:ffi/ffi.dart';

class LLMService {
  String run(String input) {
    if (!Platform.isAndroid) {
      return "FFI not supported on this platform";
    }

    final dylib = DynamicLibrary.open("libllama_lib.so");

    final runModel = dylib.lookupFunction<
        Pointer<Utf8> Function(Pointer<Utf8>),
        Pointer<Utf8> Function(Pointer<Utf8>)
    >('run_model');

    final inputPtr = input.toNativeUtf8();
    final resultPtr = runModel(inputPtr);

    final result = resultPtr.toDartString();

    malloc.free(inputPtr);
    return result;
  }
}