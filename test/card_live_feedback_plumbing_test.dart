import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepted live samples are exposed without changing capture decision', () async {
    CardLiveAnalysisSample? observed;
    final coordinator = CardLiveCaptureCoordinator(
      onAcceptedSample: (sample) => observed = sample,
      autoCapturePolicy: CardAutoCapturePolicy(
        config: const CardAutoCaptureConfig(enabled: false),
      ),
    );
    final sample = CardLiveAnalysisSample(
      quality: CardCaptureQualityAssessment.fromAnalysis(
        const CardScanQualityAnalysis(
          blur: CardScanBlurQuality(laplacianVariance: 400, score: .9),
          exposure: CardScanExposureQuality(
            meanLuma: .5,
            darkFraction: .01,
            brightFraction: .01,
            score: .95,
          ),
          glare: CardScanGlareQuality(
            specularFraction: 0,
            peakTileFraction: 0,
            score: 0,
          ),
          cardCoverage: .5,
          detectionConfidence: .9,
        ),
      ),
      detection: _detection,
    );

    final decision = await coordinator.submit(sample);

    expect(observed, same(sample));
    expect(decision, isNotNull);
    expect(decision!.shouldCapture, isFalse);
  });
}

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
