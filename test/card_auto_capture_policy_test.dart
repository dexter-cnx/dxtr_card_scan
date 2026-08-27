import 'package:dxtr_card_scan/dxtr_card_scan_advanced.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auto capture is disabled by default even when ready', () {
    final policy = CardAutoCapturePolicy();
    final decision = policy.evaluate(
      quality: _quality(),
      stability: _stable(),
    );

    expect(decision.state, CardAutoCaptureState.ready);
    expect(decision.shouldCapture, isFalse);
  });

  test('low detection confidence remains searching', () {
    final policy = CardAutoCapturePolicy();
    final decision = policy.evaluate(
      quality: _quality(detectionConfidence: .2),
      stability: _unstable(),
    );

    expect(decision.state, CardAutoCaptureState.searching);
  });

  test('detected state waits for quality and stability', () {
    final policy = CardAutoCapturePolicy();
    final decision = policy.evaluate(
      quality: _quality(score: .7),
      stability: _unstable(),
    );

    expect(decision.state, CardAutoCaptureState.detected);
    expect(decision.shouldCapture, isFalse);
  });

  test('enabled policy enters cooldown only after dispatch is marked', () {
    var now = DateTime(2026, 8, 26, 10);
    final policy = CardAutoCapturePolicy(
      config: const CardAutoCaptureConfig(
        enabled: true,
        cooldown: Duration(milliseconds: 800),
      ),
      clock: () => now,
    );

    final first = policy.evaluate(quality: _quality(), stability: _stable());
    final stillReady = policy.evaluate(
      quality: _quality(),
      stability: _stable(),
    );

    expect(first.shouldCapture, isTrue);
    expect(stillReady.shouldCapture, isTrue);

    policy.markCaptureDispatched();
    final cooling = policy.evaluate(quality: _quality(), stability: _stable());
    now = now.add(const Duration(milliseconds: 801));
    final next = policy.evaluate(quality: _quality(), stability: _stable());

    expect(cooling.state, CardAutoCaptureState.cooldown);
    expect(cooling.shouldCapture, isFalse);
    expect(next.shouldCapture, isTrue);
  });
}

CardCaptureQualityAssessment _quality({
  double score = .95,
  double detectionConfidence = .95,
}) {
  final analysis = CardScanQualityAnalysis(
    blur: const CardScanBlurQuality(laplacianVariance: 120, score: .9),
    exposure: const CardScanExposureQuality(
      meanLuma: .5,
      darkFraction: .01,
      brightFraction: .01,
      score: .95,
    ),
    cardCoverage: .45,
    detectionConfidence: detectionConfidence,
  );
  final base = CardCaptureQualityAssessment.fromAnalysis(analysis);
  return CardCaptureQualityAssessment(
    analysis: analysis,
    issues: base.issues,
    score: score,
  );
}

CardCaptureStabilitySnapshot _stable() => const CardCaptureStabilitySnapshot(
      stableFrameCount: 6,
      requiredStableFrames: 6,
      maxCornerDisplacement: .002,
      coverageDelta: .001,
      issue: null,
    );

CardCaptureStabilitySnapshot _unstable() => const CardCaptureStabilitySnapshot(
      stableFrameCount: 2,
      requiredStableFrames: 6,
      maxCornerDisplacement: .01,
      coverageDelta: .01,
      issue: null,
    );
