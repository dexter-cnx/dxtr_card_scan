import 'package:dxtr_card_scan/dxtr_card_scan_advanced.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('becomes stable after required consecutive frames', () {
    final tracker = CardCaptureStabilityTracker(
      config: const CardCaptureStabilityConfig(requiredStableFrames: 3),
    );

    final first = tracker.addSample(
      assessment: _assessment(),
      detection: _detection(),
    );
    final second = tracker.addSample(
      assessment: _assessment(cardCoverage: .401),
      detection: _detection(offset: .003),
    );
    final third = tracker.addSample(
      assessment: _assessment(cardCoverage: .402),
      detection: _detection(offset: .005),
    );

    expect(first.isStable, isFalse);
    expect(second.isStable, isFalse);
    expect(third.isStable, isTrue);
    expect(third.stableFrameCount, 3);
    expect(third.progress, 1);
  });

  test('cyclic quad corner shifts do not reset a stable streak', () {
    final tracker = CardCaptureStabilityTracker(
      config: const CardCaptureStabilityConfig(
        requiredStableFrames: 2,
        maximumCornerDisplacement: .01,
      ),
    );

    tracker.addSample(
      assessment: _assessment(),
      detection: _detection(),
    );
    final shifted = tracker.addSample(
      assessment: _assessment(cardCoverage: .401),
      detection: _detection(offset: .003, cyclicShift: 1),
    );

    expect(shifted.issue, isNull);
    expect(shifted.isStable, isTrue);
    expect(shifted.maxCornerDisplacement, lessThan(.01));
  });

  test('movement resets the stable streak to the current frame', () {
    final tracker = CardCaptureStabilityTracker(
      config: const CardCaptureStabilityConfig(
        requiredStableFrames: 3,
        maximumCornerDisplacement: .01,
      ),
    );

    tracker.addSample(
      assessment: _assessment(),
      detection: _detection(),
    );
    final moved = tracker.addSample(
      assessment: _assessment(),
      detection: _detection(offset: .05),
    );

    expect(moved.issue, CardCaptureStabilityIssue.moved);
    expect(moved.isStable, isFalse);
    expect(moved.stableFrameCount, 1);
    expect(moved.maxCornerDisplacement, greaterThan(.01));
  });

  test('blur resets the streak completely', () {
    final tracker = CardCaptureStabilityTracker();

    tracker.addSample(
      assessment: _assessment(),
      detection: _detection(),
    );
    final blurred = tracker.addSample(
      assessment: _assessment(sharpness: .20),
      detection: _detection(offset: .002),
    );

    expect(blurred.issue, CardCaptureStabilityIssue.blurry);
    expect(blurred.stableFrameCount, 0);
    expect(tracker.stableFrameCount, 0);
  });

  test('missing detection resets the streak completely', () {
    final tracker = CardCaptureStabilityTracker();

    tracker.addSample(
      assessment: _assessment(),
      detection: _detection(),
    );
    final missing = tracker.addSample(
      assessment: _assessment(),
      detection: null,
    );

    expect(missing.issue, CardCaptureStabilityIssue.detectionMissing);
    expect(missing.stableFrameCount, 0);
  });
}

CardCaptureQualityAssessment _assessment({
  double sharpness = .80,
  double cardCoverage = .40,
}) {
  return CardCaptureQualityAssessment.fromAnalysis(
    CardScanQualityAnalysis(
      blur: CardScanBlurQuality(
        laplacianVariance: 100,
        score: sharpness,
      ),
      exposure: const CardScanExposureQuality(
        meanLuma: .50,
        darkFraction: .02,
        brightFraction: .02,
        score: .95,
      ),
      cardCoverage: cardCoverage,
      detectionConfidence: .90,
    ),
  );
}

CardScanDetection _detection({
  double offset = 0,
  int cyclicShift = 0,
}) {
  ProcessorPoint point(double x, double y) => ProcessorPoint(x + offset, y);

  final points = <ProcessorPoint>[
    point(.20, .30),
    point(.80, .30),
    point(.80, .70),
    point(.20, .70),
  ];
  final shifted = List<ProcessorPoint>.generate(
    points.length,
    (index) => points[(index + cyclicShift) % points.length],
  );

  return CardScanDetection(
    quad: ProcessorQuad(
      topLeft: shifted[0],
      topRight: shifted[1],
      bottomRight: shifted[2],
      bottomLeft: shifted[3],
    ),
    score: const CardScanDetectionScore(
      total: .90,
      area: .90,
      rectangularity: .90,
      aspectRatio: .90,
      alignment: .90,
      edgeStrength: .90,
    ),
  );
}
