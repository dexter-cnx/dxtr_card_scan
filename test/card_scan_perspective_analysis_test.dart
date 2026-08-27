import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('front-facing rectangle scores near perfect perspective', () {
    final analysis = CardScanPerspectiveAnalysis.fromDetection(
      _detection(
        const ProcessorQuad(
          topLeft: ProcessorPoint(.1, .2),
          topRight: ProcessorPoint(.9, .2),
          bottomRight: ProcessorPoint(.9, .8),
          bottomLeft: ProcessorPoint(.1, .8),
        ),
      ),
    );

    expect(analysis.oppositeEdgeBalance, closeTo(1, 1e-9));
    expect(analysis.parallelismScore, closeTo(1, 1e-9));
    expect(analysis.perspectiveScore, closeTo(1, 1e-9));
    expect(analysis.alignmentScore, .91);
  });

  test('keystone distortion lowers perspective score', () {
    final square = CardScanPerspectiveAnalysis.fromDetection(
      _detection(
        const ProcessorQuad(
          topLeft: ProcessorPoint(.1, .2),
          topRight: ProcessorPoint(.9, .2),
          bottomRight: ProcessorPoint(.9, .8),
          bottomLeft: ProcessorPoint(.1, .8),
        ),
      ),
    );
    final keystone = CardScanPerspectiveAnalysis.fromDetection(
      _detection(
        const ProcessorQuad(
          topLeft: ProcessorPoint(.28, .2),
          topRight: ProcessorPoint(.72, .2),
          bottomRight: ProcessorPoint(.92, .8),
          bottomLeft: ProcessorPoint(.08, .8),
        ),
      ),
    );

    expect(keystone.perspectiveScore, lessThan(square.perspectiveScore));
    expect(keystone.oppositeEdgeBalance, lessThan(1));
  });
}

CardScanDetection _detection(ProcessorQuad quad) => CardScanDetection(
      quad: quad,
      score: const CardScanDetectionScore(
        total: .9,
        area: .9,
        rectangularity: .9,
        aspectRatio: .9,
        alignment: .91,
        edgeStrength: .9,
      ),
    );
