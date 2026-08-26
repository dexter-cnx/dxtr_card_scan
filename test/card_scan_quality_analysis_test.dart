import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses quality analysis JSON', () {
    final analysis = CardScanQualityAnalysis.fromJson({
      'blur': {
        'laplacian_variance': 123.4,
        'score': 0.8,
      },
      'exposure': {
        'mean_luma': 0.52,
        'dark_fraction': 0.03,
        'bright_fraction': 0.02,
        'score': 0.91,
      },
      'card_coverage': 0.43,
      'detection_confidence': 0.87,
    });

    expect(analysis.blur.laplacianVariance, 123.4);
    expect(analysis.blur.score, 0.8);
    expect(analysis.exposure.meanLuma, 0.52);
    expect(analysis.exposure.darkFraction, 0.03);
    expect(analysis.exposure.brightFraction, 0.02);
    expect(analysis.exposure.score, 0.91);
    expect(analysis.cardCoverage, 0.43);
    expect(analysis.detectionConfidence, 0.87);
  });

  test('quality assessment reports advisory issues', () {
    const analysis = CardScanQualityAnalysis(
      blur: CardScanBlurQuality(
        laplacianVariance: 42,
        score: .40,
      ),
      exposure: CardScanExposureQuality(
        meanLuma: .20,
        darkFraction: .40,
        brightFraction: .02,
        score: .50,
      ),
      cardCoverage: .20,
      detectionConfidence: .45,
    );

    final assessment = CardCaptureQualityAssessment.fromAnalysis(analysis);

    expect(
      assessment.issues,
      containsAll(<CardCaptureQualityIssue>{
        CardCaptureQualityIssue.blurry,
        CardCaptureQualityIssue.tooDark,
        CardCaptureQualityIssue.lowDetectionConfidence,
      }),
    );
    expect(
      assessment.issues,
      isNot(contains(CardCaptureQualityIssue.cardTooSmall)),
    );
    expect(assessment.primaryIssue, CardCaptureQualityIssue.blurry);
    expect(assessment.hasIssues, isTrue);
    expect(assessment.score, .20);
  });

  test('mean luminance catches unclipped underexposure', () {
    const analysis = CardScanQualityAnalysis(
      blur: CardScanBlurQuality(laplacianVariance: 120, score: .85),
      exposure: CardScanExposureQuality(
        meanLuma: .18,
        darkFraction: 0,
        brightFraction: 0,
        score: .36,
      ),
      cardCoverage: .50,
      detectionConfidence: .90,
    );

    final assessment = CardCaptureQualityAssessment.fromAnalysis(analysis);

    expect(assessment.primaryIssue, CardCaptureQualityIssue.tooDark);
  });

  test('mean luminance catches unclipped overexposure', () {
    const analysis = CardScanQualityAnalysis(
      blur: CardScanBlurQuality(laplacianVariance: 120, score: .85),
      exposure: CardScanExposureQuality(
        meanLuma: .86,
        darkFraction: 0,
        brightFraction: 0,
        score: .28,
      ),
      cardCoverage: .50,
      detectionConfidence: .90,
    );

    final assessment = CardCaptureQualityAssessment.fromAnalysis(analysis);

    expect(assessment.primaryIssue, CardCaptureQualityIssue.tooBright);
  });

  test('missing detection reports confidence rather than card size', () {
    const analysis = CardScanQualityAnalysis(
      blur: CardScanBlurQuality(laplacianVariance: 120, score: .85),
      exposure: CardScanExposureQuality(
        meanLuma: .50,
        darkFraction: .02,
        brightFraction: .02,
        score: .96,
      ),
      cardCoverage: 0,
      detectionConfidence: 0,
    );

    final assessment = CardCaptureQualityAssessment.fromAnalysis(analysis);

    expect(
      assessment.issues,
      contains(CardCaptureQualityIssue.lowDetectionConfidence),
    );
    expect(
      assessment.issues,
      isNot(contains(CardCaptureQualityIssue.cardTooSmall)),
    );
    expect(
      assessment.primaryIssue,
      CardCaptureQualityIssue.lowDetectionConfidence,
    );
  });

  test('quality thresholds are configurable', () {
    const analysis = CardScanQualityAnalysis(
      blur: CardScanBlurQuality(
        laplacianVariance: 100,
        score: .70,
      ),
      exposure: CardScanExposureQuality(
        meanLuma: .50,
        darkFraction: .05,
        brightFraction: .05,
        score: .90,
      ),
      cardCoverage: .40,
      detectionConfidence: .75,
    );

    final defaultAssessment =
        CardCaptureQualityAssessment.fromAnalysis(analysis);
    final strictAssessment = CardCaptureQualityAssessment.fromAnalysis(
      analysis,
      thresholds: const CardCaptureQualityThresholds(
        minimumSharpnessScore: .80,
        minimumCardCoverage: .50,
        minimumDetectionConfidence: .80,
      ),
    );

    expect(defaultAssessment.issues, isEmpty);
    expect(
      strictAssessment.issues,
      containsAll(<CardCaptureQualityIssue>{
        CardCaptureQualityIssue.blurry,
        CardCaptureQualityIssue.lowDetectionConfidence,
      }),
    );
    expect(
      strictAssessment.issues,
      isNot(contains(CardCaptureQualityIssue.cardTooSmall)),
    );
  });
}
