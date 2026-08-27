import '../geometry/normalized_rect.dart';
import 'card_capture_image.dart';
import 'card_capture_quality_metadata.dart';

export '../geometry/normalized_rect.dart';

/// Final result produced by [CardCaptureView]'s capture pipeline.
class CardCaptureResult {
  const CardCaptureResult({
    required this.original,
    required this.cropped,
    required this.processed,
    required this.sourceRoi,
    this.qualityMetadata,
  });

  /// Full camera image before frame cropping or processing.
  final CardCaptureImage original;

  /// Frame-cropped and perspective-rectified image before enhancement.
  final CardCaptureImage cropped;

  /// Final image after configured enhancement/resize/encoding.
  final CardCaptureImage processed;

  /// Capture-frame ROI mapped back into the normalized source image.
  final NormalizedRect sourceRoi;

  /// Optional quality/detection snapshot associated with this capture.
  ///
  /// Null preserves compatibility for gallery/manual flows or capture paths
  /// that did not have an eligible live-analysis sample at shutter time.
  final CardCaptureQualityMetadata? qualityMetadata;
}
