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
}