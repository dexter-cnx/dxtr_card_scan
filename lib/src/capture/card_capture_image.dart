import 'dart:io';
import 'dart:typed_data';

/// File-backed image emitted by the high-level capture pipeline.
///
/// Paths are the primary representation to avoid copying multi-megabyte image
/// buffers between isolates. Call [readBytes] only when the host needs bytes.
class CardCaptureImage {
  const CardCaptureImage({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;

  Future<Uint8List> readBytes() => File(path).readAsBytes();
}
