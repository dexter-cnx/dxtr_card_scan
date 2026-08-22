import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses detection score and expands bounding rect with padding', () {
    final detection = CardScanDetection.fromJson(<String, Object?>{
      'quad': <String, Object?>{
        'corners': <Object?>[
          <String, Object?>{'x': .10, 'y': .20},
          <String, Object?>{'x': .80, 'y': .15},
          <String, Object?>{'x': .85, 'y': .75},
          <String, Object?>{'x': .12, 'y': .80},
        ],
      },
      'score': <String, Object?>{
        'total': .82,
        'area': .80,
        'rectangularity': .90,
        'aspect_ratio': .95,
        'alignment': .75,
        'edge_strength': .60,
      },
    });

    expect(detection.confidence, .82);
    expect(
      detection.boundingRect(padding: .02),
      const NormalizedRect(left: .08, top: .13, right: .87, bottom: .82),
    );
  });

  test('bounding rect clamps padding to normalized image bounds', () {
    const detection = CardScanDetection(
      quad: ProcessorQuad(
        topLeft: ProcessorPoint(.01, .02),
        topRight: ProcessorPoint(.99, .01),
        bottomRight: ProcessorPoint(.98, .99),
        bottomLeft: ProcessorPoint(.02, .98),
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

    expect(
      detection.boundingRect(padding: .05),
      const NormalizedRect(left: 0, top: 0, right: 1, bottom: 1),
    );
  });
}
