import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses quality and detection from one native payload', () {
    final result = CardScanFrameAnalysis.fromJson({
      'blur': {'laplacian_variance': 120.0, 'score': .9},
      'exposure': {
        'mean_luma': .5,
        'dark_fraction': .01,
        'bright_fraction': .02,
        'score': .95,
      },
      'card_coverage': .42,
      'detection_confidence': .88,
      'detection': {
        'quad': {
          'corners': [
            {'x': .2, 'y': .3},
            {'x': .8, 'y': .3},
            {'x': .8, 'y': .7},
            {'x': .2, 'y': .7},
          ],
        },
        'score': {
          'total': .88,
          'area': .8,
          'rectangularity': .9,
          'aspect_ratio': .95,
          'alignment': .9,
          'edge_strength': .8,
        },
      },
    });

    expect(result.quality.detectionConfidence, .88);
    expect(result.detection, isNotNull);
    expect(result.detection!.score.total, .88);
  });

  test('allows a quality payload without detection', () {
    final result = CardScanFrameAnalysis.fromJson({
      'blur': {'laplacian_variance': 0.0, 'score': 0.0},
      'exposure': {
        'mean_luma': .5,
        'dark_fraction': 0.0,
        'bright_fraction': 0.0,
        'score': 1.0,
      },
      'card_coverage': 0.0,
      'detection_confidence': 0.0,
      'detection': null,
    });

    expect(result.detection, isNull);
  });
}
