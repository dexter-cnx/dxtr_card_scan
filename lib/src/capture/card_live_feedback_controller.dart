import 'package:flutter/foundation.dart';

import '../ui/card_corner_feedback_overlay.dart';
import 'card_capture_quality_metadata.dart';
import 'card_live_capture_coordinator.dart';

/// Lifecycle-friendly bridge from accepted live samples to advisory corner UI.
///
/// Attach [accept] to `CardLiveCaptureCoordinator.onAcceptedSample`, then use
/// this controller as a [ValueListenable] to rebuild only the corner-feedback
/// overlay. It does not participate in stability or auto-capture decisions.
class CardLiveFeedbackController
    extends ValueNotifier<CardCornerFeedback?> {
  CardLiveFeedbackController() : super(null);

  CardLiveAnalysisSample? _latestSample;
  CardCaptureQualityMetadata? _frozenCaptureMetadata;

  /// Quality metadata frozen at the most recent shutter dispatch.
  CardCaptureQualityMetadata? get frozenCaptureMetadata =>
      _frozenCaptureMetadata;

  /// Converts one accepted live-analysis sample into corner feedback.
  ///
  /// A sample without a detection clears the current overlay so stale corners
  /// are never left visible after detection is lost. The accepted sample is
  /// also retained until live analysis becomes ineligible or capture freezes it.
  void accept(CardLiveAnalysisSample sample) {
    _latestSample = sample;
    final detection = sample.detection;
    value = detection == null
        ? null
        : CardCornerFeedback.fromDetection(
            detection,
            imageAspectRatio: sample.imageAspectRatio,
          );
  }

  /// Freezes the latest eligible live sample for the capture being dispatched.
  ///
  /// This must run before the live stream is paused. A later [clear] may remove
  /// advisory UI/latest-sample state without discarding the shutter snapshot.
  void freezeForCapture() {
    final sample = _latestSample;
    _frozenCaptureMetadata = sample == null
        ? null
        : CardCaptureQualityMetadata(
            quality: sample.quality,
            detection: sample.detection,
            imageAspectRatio: sample.imageAspectRatio,
          );
  }

  /// Clears metadata retained for the current/previous capture attempt.
  void clearFrozenCapture() => _frozenCaptureMetadata = null;

  /// Clears current advisory feedback and live-sample eligibility state.
  void clear() {
    _latestSample = null;
    value = null;
  }
}
