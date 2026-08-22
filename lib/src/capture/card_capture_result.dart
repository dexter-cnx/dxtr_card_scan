import '../geometry/normalized_rect.dart';
import 'card_capture_image.dart';

/// Final result produced by [CardCaptureView]'s capture pipeline.
class CardCaptureResult {
  const CardCaptureResult({
    required this.original,
    required this.cropped,
    required this.processed,
    required this.sourceRoi,
  });

  /// Full camera image before frame cropping or processing.
  final CardCaptureImage original;

  /// Frame-cropped and perspective-rectified image before enhancement.
  final CardCaptureImage cropped;

  /// Final image after configured enhancement/resize/encoding.
  final CardCaptureImage processed;

  /// Capture-frame ROI mapped back into the normalized source image.
  final NormalizedRect sourceRoi;
}
