import 'dart:isolate';

import '../geometry/normalized_rect.dart';
import '../processor/card_scan_processor.dart';
import '../processor/card_scan_quality_analysis.dart';
import 'card_camera_image_adapter.dart';
import 'card_live_capture_coordinator.dart';

/// Encodes a mapped raw-frame ROI and runs native quality/detection analysis.
///
/// Heavy YUV/BGRA conversion, JPEG encoding and Rust FFI run on a worker
/// isolate so camera image-stream callbacks do not block Flutter's UI isolate.
class CardLiveFrameAnalyzer {
  const CardLiveFrameAnalyzer({
    this.jpegQuality = 80,
    this.qualityThresholds = const CardCaptureQualityThresholds(),
  }) : assert(jpegQuality >= 1 && jpegQuality <= 100);

  final int jpegQuality;
  final CardCaptureQualityThresholds qualityThresholds;

  Future<CardLiveAnalysisSample> analyze(
    CardCameraFrame frame, {
    required NormalizedRect rawFrameRoi,
  }) {
    return Isolate.run(
      () => _analyzeLiveFrame(
        frame,
        rawFrameRoi,
        jpegQuality,
        qualityThresholds,
      ),
    );
  }
}

CardLiveAnalysisSample _analyzeLiveFrame(
  CardCameraFrame frame,
  NormalizedRect rawFrameRoi,
  int jpegQuality,
  CardCaptureQualityThresholds thresholds,
) {
  const adapter = CardCameraImageAdapter();
  final encoded = adapter.encodeJpeg(
    frame,
    roi: rawFrameRoi,
    quality: jpegQuality,
  );
  final processor = CardScanProcessor();
  final frameAnalysis = processor.analyzeFrameBytes(encoded);

  return CardLiveAnalysisSample(
    quality: CardCaptureQualityAssessment.fromAnalysis(
      frameAnalysis.quality,
      thresholds: thresholds,
    ),
    detection: frameAnalysis.detection,
  );
}
