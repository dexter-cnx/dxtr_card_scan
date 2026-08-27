import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepted detection becomes corner feedback using sample aspect ratio', () {
    final controller = CardLiveFeedbackController();
    addTearDown(controller.dispose);

    controller.accept(
      CardLiveAnalysisSample(
        quality: _quality,
        detection: _detection,
        imageAspectRatio: 2,
      ),
    );

    final feedback = controller.value;
    expect(feedback, isNotNull);
    expect(feedback!.corners, hasLength(4));
    expect(feedback.overallConfidence, inInclusiveRange(0, 1));
  });

  test('missing detection clears stale corner feedback', () {
    final controller = CardLiveFeedbackController();
    addTearDown(controller.dispose);

    controller.accept(
      CardLiveAnalysisSample(
        quality: _quality,
        detection: _detection,
        imageAspectRatio: 1,
      ),
    );
    expect(controller.value, isNotNull);

    controller.accept(
      const CardLiveAnalysisSample(
        quality: _quality,
        detection: null,
      ),
    );

    expect(controller.value, isNull);
  });
}

const _quality = CardCaptureQualityAssessment(
  score: 1,
  ready: true,
  issues: <CardCaptureQualityIssue>[],
);

const _detection = CardScanDetection(
  quad: ProcessorQuad(
    topLeft: ProcessorPoint(.1, .1),
    topRight: ProcessorPoint(.9, .1),
    bottomRight: ProcessorPoint(.9, .9),
    bottomLeft: ProcessorPoint(.1, .9),
  ),
  score: CardScanDetectionScore(
    total: .9,
    area: .9,
    rectangularity: .9,
    aspectRatio: .9,
    alignment: .9,
    edgeStrength: .9,
  ),
);
