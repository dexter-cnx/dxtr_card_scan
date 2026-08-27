import '../processor/card_scan_detection.dart';
import '../processor/card_scan_quality_analysis.dart';

/// Optional analysis metadata associated with a completed card capture.
class CardCaptureQualityMetadata {
  const CardCaptureQualityMetadata({
    required this.quality,
    required this.detection,
    required this.imageAspectRatio,
  }) : assert(imageAspectRatio > 0 && imageAspectRatio.isFinite);

  final CardCaptureQualityAssessment quality;
  final CardScanDetection? detection;
  final double imageAspectRatio;
}
