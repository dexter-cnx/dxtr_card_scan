import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overlay layer hides without feedback and rebuilds when available',
      (tester) async {
    final controller = CardLiveFeedbackController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: CardLiveFeedbackOverlayLayer(
            controller: controller,
            frameRect: const Rect.fromLTWH(20, 30, 200, 120),
          ),
        ),
      ),
    );

    expect(find.byType(CardCornerFeedbackOverlay), findsNothing);

    controller.value = const CardCornerFeedback(
      corners: [
        CardCornerConfidence(point: ProcessorPoint(.1, .1), score: .9),
        CardCornerConfidence(point: ProcessorPoint(.9, .1), score: .9),
        CardCornerConfidence(point: ProcessorPoint(.9, .9), score: .9),
        CardCornerConfidence(point: ProcessorPoint(.1, .9), score: .9),
      ],
      overallConfidence: .9,
    );
    await tester.pump();

    expect(find.byType(CardCornerFeedbackOverlay), findsOneWidget);
  });
}
