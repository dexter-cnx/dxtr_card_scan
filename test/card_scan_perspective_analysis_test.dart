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
      imageAspectRatio: 1,
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
      imageAspectRatio: 1,
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
      imageAspectRatio: 1,
    );

    expect(keystone.perspectiveScore, lessThan(square.perspectiveScore));
    expect(keystone.oppositeEdgeBalance, lessThan(1));
  });

  test('equivalent pixel geometry is invariant to image aspect ratio', () {
    final square = CardScanPerspectiveAnalysis.fromDetection(
      _detection(
        const ProcessorQuad(
          topLeft: ProcessorPoint(.10, .20),
          topRight: ProcessorPoint(.90, .20),
          bottomRight: ProcessorPoint(.85, .80),
          bottomLeft: ProcessorPoint(.15, .80),
        ),
      ),
      imageAspectRatio: 1,
    );
    final wide = CardScanPerspectiveAnalysis.fromDetection(
      _detection(
        const ProcessorQuad(
          topLeft: ProcessorPoint(.30, .20),
          topRight: ProcessorPoint(.70, .20),
          bottomRight: ProcessorPoint(.675, .80),
          bottomLeft: ProcessorPoint(.325, .80),
        ),
      ),
      imageAspectRatio: 2,
    );

    expect(wide.oppositeEdgeBalance, closeTo(square.oppositeEdgeBalance, 1e-9));
    expect(wide.parallelismScore, closeTo(square.parallelismScore, 1e-9));
    expect(wide.perspectiveScore, closeTo(square.perspectiveScore, 1e-9));
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
