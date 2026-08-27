import 'package:flutter/foundation.dart';

import '../ui/card_corner_feedback_overlay.dart';
import 'card_live_capture_coordinator.dart';

/// Lifecycle-friendly bridge from accepted live samples to advisory corner UI.
///
/// Attach [accept] to `CardLiveCaptureCoordinator.onAcceptedSample`, then use
/// this controller as a [ValueListenable] to rebuild only the corner-feedback
/// overlay. It does not participate in stability or auto-capture decisions.
class CardLiveFeedbackController
    extends ValueNotifier<CardCornerFeedback?> {
  CardLiveFeedbackController() : super(null);

  /// Converts one accepted live-analysis sample into corner feedback.
  ///
  /// A sample without a detection clears the current overlay so stale corners
  /// are never left visible after detection is lost.
  void accept(CardLiveAnalysisSample sample) {
    final detection = sample.detection;
    value = detection == null
        ? null
        : CardCornerFeedback.fromDetection(
            detection,
            imageAspectRatio: sample.imageAspectRatio,
          );
  }

  /// Clears any currently displayed advisory feedback.
  void clear() => value = null;
}
