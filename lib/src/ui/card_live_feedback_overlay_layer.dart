import 'package:flutter/material.dart';

import '../capture/card_live_feedback_controller.dart';
import 'card_corner_feedback_overlay.dart';

/// Lifecycle-safe UI bridge from [CardLiveFeedbackController] to the reusable
/// corner overlay.
///
/// The layer is advisory-only and performs no image analysis. The caller owns
/// the controller and supplies the resolved capture-frame rectangle.
class CardLiveFeedbackOverlayLayer extends StatelessWidget {
  const CardLiveFeedbackOverlayLayer({
    required this.controller,
    required this.frameRect,
    this.minimumVisibleConfidence = 0,
    this.lineWidth = 2,
    this.cornerRadius = 6,
    super.key,
  });

  final CardLiveFeedbackController controller;
  final Rect frameRect;
  final double minimumVisibleConfidence;
  final double lineWidth;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, feedback, _) {
        if (feedback == null || frameRect.isEmpty) {
          return const SizedBox.shrink();
        }
        return CardCornerFeedbackOverlay(
          feedback: feedback,
          frameRect: frameRect,
          minimumVisibleConfidence: minimumVisibleConfidence,
          lineWidth: lineWidth,
          cornerRadius: cornerRadius,
        );
      },
    );
  }
}
