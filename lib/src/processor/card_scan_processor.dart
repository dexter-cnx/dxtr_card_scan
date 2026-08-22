import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'card_scan_detection.dart';
import 'card_scan_processor_options.dart';

final class _NativeCardScanResult extends Struct {
  @Int32()
  external int status;

  external Pointer<Uint8> dataPtr;

  @IntPtr()
  external int dataLen;

  external Pointer<Utf8> errorPtr;
}

typedef _ProcessNative = Pointer<_NativeCardScanResult> Function(
  Pointer<Uint8>,
  IntPtr,
  Pointer<Uint8>,
  IntPtr,
);
typedef _ProcessDart = Pointer<_NativeCardScanResult> Function(
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
  int,
);
typedef _DetectNative = Pointer<_NativeCardScanResult> Function(
  Pointer<Uint8>,
  IntPtr,
);
typedef _DetectDart = Pointer<_NativeCardScanResult> Function(
  Pointer<Uint8>,
  int,
);
typedef _FreeNative = Void Function(Pointer<_NativeCardScanResult>);
typedef _FreeDart = void Function(Pointer<_NativeCardScanResult>);

class CardScanProcessorException implements Exception {
  const CardScanProcessorException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() =>
      'CardScanProcessorException(status: $status, message: $message)';
}

/// Dart wrapper around the Rust image-processing ABI.
class CardScanProcessor {
  CardScanProcessor({DynamicLibrary? library})
      : _library = library ?? _openLibrary() {
    _process = _library.lookupFunction<_ProcessNative, _ProcessDart>(
      'card_scan_process',
    );
    _detect = _library.lookupFunction<_DetectNative, _DetectDart>(
      'card_scan_detect',
    );
    _free = _library.lookupFunction<_FreeNative, _FreeDart>(
      'card_scan_result_free',
    );
  }

  final DynamicLibrary _library;
  late final _ProcessDart _process;
  late final _DetectDart _detect;
  late final _FreeDart _free;

  Uint8List processBytes(
    Uint8List input, {
    CardScanProcessorOptions options = const CardScanProcessorOptions(),
  }) {
    if (input.isEmpty) {
      throw ArgumentError('input image must not be empty');
    }

    final optionsBytes = Uint8List.fromList(utf8.encode(options.toJsonString()));
    final inputPtr = calloc<Uint8>(input.length);
    final optionsPtr = calloc<Uint8>(optionsBytes.length);
    try {
      inputPtr.asTypedList(input.length).setAll(0, input);
      if (optionsBytes.isNotEmpty) {
        optionsPtr.asTypedList(optionsBytes.length).setAll(0, optionsBytes);
      }
      return _copyResult(
        _process(inputPtr, input.length, optionsPtr, optionsBytes.length),
      );
    } finally {
      calloc.free(inputPtr);
      calloc.free(optionsPtr);
    }
  }

  Future<Uint8List> processFile(
    String path, {
    CardScanProcessorOptions options = const CardScanProcessorOptions(),
  }) async {
    final bytes = await File(path).readAsBytes();
    return processBytes(bytes, options: options);
  }

  CardScanDetection? detectBytes(Uint8List input) {
    if (input.isEmpty) {
      throw ArgumentError('input image must not be empty');
    }

    final inputPtr = calloc<Uint8>(input.length);
    try {
      inputPtr.asTypedList(input.length).setAll(0, input);
      final output = _copyResult(_detect(inputPtr, input.length));
      final decoded = jsonDecode(utf8.decode(output));
      if (decoded == null) return null;
      return CardScanDetection.fromJson(
        (decoded as Map<Object?, Object?>).cast<String, Object?>(),
      );
    } finally {
      calloc.free(inputPtr);
    }
  }

  Future<CardScanDetection?> detectFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return detectBytes(bytes);
  }

  Uint8List _copyResult(Pointer<_NativeCardScanResult> resultPtr) {
    if (resultPtr == nullptr) {
      throw const CardScanProcessorException(
        -1,
        'native processor returned a null result',
      );
    }

    try {
      final result = resultPtr.ref;
      if (result.status != 0) {
        final message = result.errorPtr == nullptr
            ? 'native processor failed without an error message'
            : result.errorPtr.toDartString();
        throw CardScanProcessorException(result.status, message);
      }
      if (result.dataPtr == nullptr || result.dataLen <= 0) {
        throw const CardScanProcessorException(
          -1,
          'native processor returned empty output',
        );
      }
      return Uint8List.fromList(result.dataPtr.asTypedList(result.dataLen));
    } finally {
      _free(resultPtr);
    }
  }

  static DynamicLibrary _openLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libdxtr_card_scan_processor.so');
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.process();
    }
    throw UnsupportedError(
      'CardScanProcessor currently supports Android, iOS, and macOS',
    );
  }
}
