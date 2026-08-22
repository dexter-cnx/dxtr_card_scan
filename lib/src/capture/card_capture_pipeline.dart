import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;

import '../geometry/normalized_rect.dart';
import '../processor/card_scan_detection.dart';
import '../processor/card_scan_processor.dart';
import '../processor/card_scan_processor_options.dart';
import 'card_capture_image.dart';

class PreparedCardCapture {
  const PreparedCardCapture({
    required this.original,
    required this.normalized,
  });

  final CardCaptureImage original;
  final CardCaptureImage normalized;
}

/// Package-owned background pipeline used by [CardCaptureView].
///
/// Image decode/orientation and synchronous Rust FFI work are kept off the UI
/// isolate. Intermediate files live in system temporary storage.
class CardCapturePipeline {
  const CardCapturePipeline();

  Future<PreparedCardCapture> prepare(String sourcePath) {
    return Isolate.run(() {
      final bytes = File(sourcePath).readAsBytesSync();
      final decoded = image_lib.decodeImage(bytes);
      if (decoded == null) {
        throw StateError('Unable to decode captured image.');
      }

      final normalized = image_lib.bakeOrientation(decoded);
      final directory = Directory.systemTemp.createTempSync('dxtr_card_scan_');
      final normalizedPath = '${directory.path}/normalized.jpg';
      File(normalizedPath).writeAsBytesSync(
        image_lib.encodeJpg(normalized, quality: 96),
        flush: true,
      );

      return PreparedCardCapture(
        original: CardCaptureImage(
          path: sourcePath,
          width: decoded.width,
          height: decoded.height,
        ),
        normalized: CardCaptureImage(
          path: normalizedPath,
          width: normalized.width,
          height: normalized.height,
        ),
      );
    });
  }

  Future<CardScanDetection?> detect(CardCaptureImage image) {
    return Isolate.run(() => CardScanProcessor().detectFile(image.path));
  }

  Future<CardCaptureImage> cropAndRectify({
    required CardCaptureImage normalized,
    required NormalizedRect sourceRoi,
    required CardScanProcessorOptions options,
  }) {
    return Isolate.run(() {
      final processor = CardScanProcessor();
      final bytes = processor.processFile(
        normalized.path,
        options: CardScanProcessorOptions(
          quarterTurnsClockwise: options.quarterTurnsClockwise,
          roi: sourceRoi,
          autoDetect: options.autoDetect,
          perspectiveQuad: options.perspectiveQuad,
          warpLongEdge: options.warpLongEdge,
          outputFormat: ProcessorOutputFormat.jpeg,
          jpegQuality: 96,
        ),
      );
      return bytes.then((output) {
        final path = '${File(normalized.path).parent.path}/cropped.jpg';
        File(path).writeAsBytesSync(output, flush: true);
        return _describeImage(path, output);
      });
    });
  }

  Future<CardCaptureImage> process({
    required CardCaptureImage cropped,
    required CardScanProcessorOptions options,
  }) {
    return Isolate.run(() {
      final processor = CardScanProcessor();
      final bytes = processor.processFile(
        cropped.path,
        options: CardScanProcessorOptions(
          enhanceForOcr: options.enhanceForOcr,
          grayscale: options.grayscale,
          maxDimension: options.maxDimension,
          outputFormat: options.outputFormat,
          jpegQuality: options.jpegQuality,
        ),
      );
      return bytes.then((output) {
        final extension = options.outputFormat == ProcessorOutputFormat.png
            ? 'png'
            : 'jpg';
        final path = '${File(cropped.path).parent.path}/processed.$extension';
        File(path).writeAsBytesSync(output, flush: true);
        return _describeImage(path, output);
      });
    });
  }
}

CardCaptureImage _describeImage(String path, Uint8List bytes) {
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Unable to decode processor output.');
  }
  return CardCaptureImage(
    path: path,
    width: decoded.width,
    height: decoded.height,
  );
}
