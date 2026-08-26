import 'card_capture_stability_tracker.dart';
import '../processor/card_scan_quality_analysis.dart';

/// High-level live capture state derived from quality and temporal stability.
enum CardAutoCaptureState {
  searching,
  detected,
  ready,
  cooldown,
}

/// Configuration for optional quality-gated auto capture.
///
/// Auto capture remains disabled by default for backward compatibility. The
/// aggregate quality-score gate is also disabled by default because the SC-01
/// score includes card coverage and still requires physical calibration.
class CardAutoCaptureConfig {
  const CardAutoCaptureConfig({
    this.enabled = false,
    this.minimumQualityScore = 0,
    this.cooldown = const Duration(milliseconds: 800),
  }) : assert(minimumQualityScore >= 0 && minimumQualityScore <= 1);

  final bool enabled;

  /// Optional aggregate score gate. Keep at zero to rely on explicit quality
  /// issues plus temporal stability until calibrated evidence supports a score
  /// threshold.
  final double minimumQualityScore;

  final Duration cooldown;
}

/// One deterministic policy evaluation for a live analysis sample.
class CardAutoCaptureDecision {
  const CardAutoCaptureDecision({
    required this.state,
    required this.shouldCapture,
    required this.quality,
    required this.stability,
  });

  final CardAutoCaptureState state;
  final bool shouldCapture;
  final CardCaptureQualityAssessment quality;
  final CardCaptureStabilitySnapshot stability;
}

/// Pure state machine that combines SC-01 quality and SC-03 stability.
///
/// The policy never invokes a camera controller itself. Hosts/package camera
/// integration may act on [CardAutoCaptureDecision.shouldCapture].
class CardAutoCapturePolicy {
  CardAutoCapturePolicy({
    this.config = const CardAutoCaptureConfig(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CardAutoCaptureConfig config;
  final DateTime Function() _clock;

  DateTime? _cooldownUntil;

  bool get isCoolingDown {
    final until = _cooldownUntil;
    return until != null && _clock().isBefore(until);
  }

  void reset() {
    _cooldownUntil = null;
  }

  CardAutoCaptureDecision evaluate({
    required CardCaptureQualityAssessment quality,
    required CardCaptureStabilitySnapshot stability,
  }) {
    final now = _clock();
    final cooldownUntil = _cooldownUntil;
    if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
      return CardAutoCaptureDecision(
        state: CardAutoCaptureState.cooldown,
        shouldCapture: false,
        quality: quality,
        stability: stability,
      );
    }

    if (cooldownUntil != null) {
      _cooldownUntil = null;
    }

    if (quality.analysis.detectionConfidence == 0 ||
        quality.issues.contains(CardCaptureQualityIssue.lowDetectionConfidence)) {
      return CardAutoCaptureDecision(
        state: CardAutoCaptureState.searching,
        shouldCapture: false,
        quality: quality,
        stability: stability,
      );
    }

    final qualityReady = !quality.hasIssues &&
        quality.score >= config.minimumQualityScore;
    if (!qualityReady || !stability.isStable) {
      return CardAutoCaptureDecision(
        state: CardAutoCaptureState.detected,
        shouldCapture: false,
        quality: quality,
        stability: stability,
      );
    }

    final shouldCapture = config.enabled;
    if (shouldCapture && config.cooldown > Duration.zero) {
      _cooldownUntil = now.add(config.cooldown);
    }

    return CardAutoCaptureDecision(
      state: CardAutoCaptureState.ready,
      shouldCapture: shouldCapture,
      quality: quality,
      stability: stability,
    );
  }
}
