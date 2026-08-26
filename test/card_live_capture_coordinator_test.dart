import 'dart:async';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('throttles samples before stability tracking advances', () async {
    var now = DateTime(2026, 1, 1);
    final coordinator = CardLiveCaptureCoordinator(
      capture: () async => null,
      analysisInterval: const Duration(milliseconds: 200),
      clock: () => now,
      stabilityTracker: CardCaptureStabilityTracker(
        config: const CardCaptureStabilityConfig(requiredStableFrames: 2),
      ),
    );

    final first = await coordinator.submit(_sample());
    final throttled = await coordinator.submit(_sample());
    now = now.add(const Duration(milliseconds: 200));
    final second = await coordinator.submit(_sample(offset: .002));

    expect(first, isNotNull);
    expect(throttled, isNull);
    expect(second?.state, CardAutoCaptureState.ready);
    expect(coordinator.stableFrameCount, 2);
  });

  test('fires one package capture when quality and stability are ready', () async {
    var now = DateTime(2026, 1, 1);
    var captures = 0;
    final coordinator = CardLiveCaptureCoordinator(
      capture: () async {
        captures += 1;
        return null;
      },
      analysisInterval: Duration.zero,
      clock: () => now,
      stabilityTracker: CardCaptureStabilityTracker(
        config: const CardCaptureStabilityConfig(requiredStableFrames: 2),
      ),
      autoCapturePolicy: CardAutoCapturePolicy(
        config: const CardAutoCaptureConfig(
          enabled: true,
          cooldown: Duration(milliseconds: 500),
        ),
        clock: () => now,
      ),
    );

    await coordinator.submit(_sample());
    final ready = await coordinator.submit(_sample(offset: .002));
    final cooling = await coordinator.submit(_sample(offset: .003));

    expect(ready?.shouldCapture, isTrue);
    expect(captures, 1);
    expect(cooling?.state, CardAutoCaptureState.cooldown);

    now = now.add(const Duration(milliseconds: 500));
    final afterCooldown = await coordinator.submit(_sample(offset: .004));
    expect(afterCooldown?.shouldCapture, isTrue);
    expect(captures, 2);
  });

  test('prevents re-entrant shutter while capture is in flight', () async {
    final gate = Completer<void>();
    var captures = 0;
    final coordinator = CardLiveCaptureCoordinator(
      capture: () async {
        captures += 1;
        await gate.future;
        return null;
      },
      analysisInterval: Duration.zero,
      stabilityTracker: CardCaptureStabilityTracker(
        config: const CardCaptureStabilityConfig(requiredStableFrames: 1),
      ),
      autoCapturePolicy: CardAutoCapturePolicy(
        config: const CardAutoCaptureConfig(
          enabled: true,
          cooldown: Duration.zero,
        ),
      ),
    );

    final first = coordinator.submit(_sample());
    await Future<void>.delayed(Duration.zero);
    final second = await coordinator.submit(_sample(offset: .001));

    expect(second?.shouldCapture, isTrue);
    expect(coordinator.captureInFlight, isTrue);
    expect(captures, 1);

    gate.complete();
    await first;
    expect(coordinator.captureInFlight, isFalse);
  });
}

CardLiveAnalysisSample _sample({double offset = 0}) {
  const analysis = CardScanQualityAnalysis(
    blur: CardScanBlurQuality(
      laplacianVariance: 100,
      score: .90,
    ),
    exposure: CardScanExposureQuality(
      meanLuma: .50,
      darkFraction: .02,
      brightFraction: .02,
      score: .95,
    ),
    cardCoverage: .40,
    detectionConfidence: .90,
  );

  ProcessorPoint point(double x, double y) => ProcessorPoint(x + offset, y);
  final detection = CardScanDetection(
    quad: ProcessorQuad(
      topLeft: point(.20, .30),
      topRight: point(.80, .30),
      bottomRight: point(.80, .70),
      bottomLeft: point(.20, .70),
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

  return CardLiveAnalysisSample(
    quality: CardCaptureQualityAssessment.fromAnalysis(analysis),
    detection: detection,
  );
}
