import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:image/image.dart' as image_lib;

class PreparedImage {
  const PreparedImage({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}

/// Decodes the selected/captured image and physically applies its EXIF
/// orientation without blocking Flutter's UI isolate.
Future<PreparedImage> prepareImageInBackground(String path) {
  return Isolate.run(() {
    final bytes = File(path).readAsBytesSync();
    final decoded = image_lib.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unable to decode image.');
    }

    final normalized = image_lib.bakeOrientation(decoded);
    final outputPath = '$path.normalized.jpg';
    File(outputPath).writeAsBytesSync(
      image_lib.encodeJpg(normalized, quality: 96),
      flush: true,
    );

    return PreparedImage(
      path: outputPath,
      width: normalized.width,
      height: normalized.height,
    );
  });
}

/// Runs the synchronous FFI/Rust processor on a worker isolate so decoding,
/// detection, perspective warp and encoding cannot stall Flutter animations.
Future<Uint8List> processScanInBackground({
  required String imagePath,
  required NormalizedRect roi,
  required bool autoDetect,
  bool enhanceForOcr = false,
  int? warpLongEdge,
  int? maxDimension = 1600,
}) {
  final left = roi.left;
  final top = roi.top;
  final right = roi.right;
  final bottom = roi.bottom;

  return Isolate.run(() async {
    return CardScanProcessor().processFile(
      imagePath,
      options: CardScanProcessorOptions(
        roi: NormalizedRect(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
        autoDetect: autoDetect,
        enhanceForOcr: enhanceForOcr,
        warpLongEdge: warpLongEdge,
        maxDimension: maxDimension,
        outputFormat: ProcessorOutputFormat.jpeg,
        jpegQuality: 92,
      ),
    );
  });
}
