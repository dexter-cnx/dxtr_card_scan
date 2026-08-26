import '../processor/card_scan_detection.dart';
import '../processor/card_scan_quality_analysis.dart';
import 'card_auto_capture_policy.dart';
import 'card_capture_stability_tracker.dart';

typedef CardLiveCaptureTrigger = Future<Object?> Function();

/// One quality/detection sample produced by the live analysis pipeline.
class CardLiveAnalysisSample {
  const CardLiveAnalysisSample({
    required this.quality,
    required this.detection,
  });

  final CardCaptureQualityAssessment quality;
  final CardScanDetection? detection;
}

/// Coordinates throttled live-analysis samples with stability and auto-capture.
///
/// This class deliberately does not know how raw camera frames are encoded or
/// mapped. The caller must submit samples produced from the correctly mapped
/// capture-frame ROI. That keeps camera-format/orientation concerns separate
/// from the deterministic capture policy.
class CardLiveCaptureCoordinator {
  CardLiveCaptureCoordinator({
    CardCaptureStabilityTracker? stabilityTracker,
    CardAutoCapturePolicy? autoCapturePolicy,
    required this.capture,
    this.analysisInterval = const Duration(milliseconds: 180),
    DateTime Function()? clock,
  })  : _stabilityTracker =
            stabilityTracker ?? CardCaptureStabilityTracker(),
        _autoCapturePolicy = autoCapturePolicy ?? CardAutoCapturePolicy(),
        _clock = clock ?? DateTime.now;

  final CardCaptureStabilityTracker _stabilityTracker;
  final CardAutoCapturePolicy _autoCapturePolicy;
  final CardLiveCaptureTrigger capture;
  final Duration analysisInterval;
  final DateTime Function() _clock;

  DateTime? _lastAcceptedAt;
  bool _captureInFlight = false;

  bool get captureInFlight => _captureInFlight;
  int get stableFrameCount => _stabilityTracker.stableFrameCount;

  void reset() {
    _lastAcceptedAt = null;
    _captureInFlight = false;
    _stabilityTracker.reset();
    _autoCapturePolicy.reset();
  }

  /// Submits one already-analyzed ROI sample.
  ///
  /// Returns `null` when the sample is throttled. When auto capture is enabled
  /// and the policy emits `shouldCapture`, [capture] is invoked at most once at
  /// a time. Re-entrant samples cannot trigger a second shutter while the
  /// previous capture is still in flight.
  Future<CardAutoCaptureDecision?> submit(CardLiveAnalysisSample sample) async {
    final now = _clock();
    final previous = _lastAcceptedAt;
    if (previous != null && now.difference(previous) < analysisInterval) {
      return null;
    }
    _lastAcceptedAt = now;

    final stability = _stabilityTracker.addSample(
      assessment: sample.quality,
      detection: sample.detection,
    );
    final decision = _autoCapturePolicy.evaluate(
      quality: sample.quality,
      stability: stability,
    );

    if (!decision.shouldCapture || _captureInFlight) {
      return decision;
    }

    _captureInFlight = true;
    try {
      await capture();
    } finally {
      _captureInFlight = false;
    }
    return decision;
  }
}
