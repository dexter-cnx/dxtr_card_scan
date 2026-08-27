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
      CardLiveAnalysisSample(
        quality: _quality,
        detection: null,
      ),
    );

    expect(controller.value, isNull);
  });

  test('frozen metadata survives live feedback clear', () {
    final controller = CardLiveFeedbackController();
    addTearDown(controller.dispose);

    controller.accept(
      CardLiveAnalysisSample(
        quality: _quality,
        detection: _detection,
        imageAspectRatio: 2,
      ),
    );
    controller.freezeForCapture();
    controller.clear();

    final metadata = controller.frozenCaptureMetadata;
    expect(metadata, isNotNull);
    expect(metadata!.quality, same(_quality));
    expect(metadata.detection, same(_detection));
    expect(metadata.imageAspectRatio, 2);
  });

  test('ineligible live state produces no frozen metadata', () {
    final controller = CardLiveFeedbackController();
    addTearDown(controller.dispose);

    controller.accept(
      CardLiveAnalysisSample(
        quality: _quality,
        detection: _detection,
        imageAspectRatio: 2,
      ),
    );
    controller.clear();
    controller.freezeForCapture();

    expect(controller.frozenCaptureMetadata, isNull);
  });

  test('frozen metadata can be cleared after capture completes', () {
    final controller = CardLiveFeedbackController();
    addTearDown(controller.dispose);

    controller.accept(
      CardLiveAnalysisSample(
        quality: _quality,
        detection: _detection,
        imageAspectRatio: 2,
      ),
    );
    controller.freezeForCapture();
    expect(controller.frozenCaptureMetadata, isNotNull);

    controller.clearFrozenCapture();

    expect(controller.frozenCaptureMetadata, isNull);
  });
}

final _quality = CardCaptureQualityAssessment.fromAnalysis(
  const CardScanQualityAnalysis(
    blur: CardScanBlurQuality(laplacianVariance: 400, score: .9),
    exposure: CardScanExposureQuality(
      meanLuma: .5,
      darkFraction: .01,
      brightFraction: .01,
      score: .95,
    ),
    glare: CardScanGlareQuality.none(),
    cardCoverage: .5,
    detectionConfidence: .9,
  ),
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
