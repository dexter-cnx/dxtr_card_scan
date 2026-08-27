import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('front-facing corners score higher than skewed corner geometry', () {
    final square = CardCornerFeedback.fromDetection(
      _detection(
        const ProcessorQuad(
          topLeft: ProcessorPoint(.1, .2),
          topRight: ProcessorPoint(.9, .2),
          bottomRight: ProcessorPoint(.9, .8),
          bottomLeft: ProcessorPoint(.1, .8),
        ),
      ),
      imageAspectRatio: 4 / 3,
    );
    final skewed = CardCornerFeedback.fromDetection(
      _detection(
        const ProcessorQuad(
          topLeft: ProcessorPoint(.18, .2),
          topRight: ProcessorPoint(.82, .26),
          bottomRight: ProcessorPoint(.94, .82),
          bottomLeft: ProcessorPoint(.08, .72),
        ),
      ),
      imageAspectRatio: 4 / 3,
    );

    expect(square.corners, hasLength(4));
    expect(square.overallConfidence, greaterThan(skewed.overallConfidence));
  });

  test('confidence respects detector edge strength', () {
    final strong = CardCornerFeedback.fromDetection(
      _detection(_square, edgeStrength: 1),
      imageAspectRatio: 1,
    );
    final weak = CardCornerFeedback.fromDetection(
      _detection(_square, edgeStrength: .4),
      imageAspectRatio: 1,
    );

    expect(strong.overallConfidence, greaterThan(weak.overallConfidence));
    expect(weak.overallConfidence, closeTo(.4, 1e-9));
  });
}

const _square = ProcessorQuad(
  topLeft: ProcessorPoint(.1, .1),
  topRight: ProcessorPoint(.9, .1),
  bottomRight: ProcessorPoint(.9, .9),
  bottomLeft: ProcessorPoint(.1, .9),
);

CardScanDetection _detection(
  ProcessorQuad quad, {
  double edgeStrength = .9,
}) =>
    CardScanDetection(
      quad: quad,
      score: CardScanDetectionScore(
        total: .9,
        area: .9,
        rectangularity: .9,
        aspectRatio: .9,
        alignment: .9,
        edgeStrength: edgeStrength,
      ),
    );
