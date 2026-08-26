import 'dart:math' as math;

import '../processor/card_scan_detection.dart';
import '../processor/card_scan_processor_options.dart';
import '../processor/card_scan_quality_analysis.dart';

/// Why the current sample cannot advance a stable capture streak.
enum CardCaptureStabilityIssue {
  blurry,
  detectionMissing,
  lowDetectionConfidence,
  moved,
}

/// Tunable thresholds for temporal card stability.
///
/// Defaults are calibration candidates only. They remain independent from
/// auto-capture policy until physical-device evidence is complete.
class CardCaptureStabilityConfig {
  const CardCaptureStabilityConfig({
    this.requiredStableFrames = 6,
    this.minimumSharpnessScore = .55,
    this.minimumDetectionConfidence = .60,
    this.maximumCornerDisplacement = .018,
    this.maximumCoverageDelta = .025,
  })  : assert(requiredStableFrames > 0),
        assert(minimumSharpnessScore >= 0 && minimumSharpnessScore <= 1),
        assert(
          minimumDetectionConfidence >= 0 && minimumDetectionConfidence <= 1,
        ),
        assert(
          maximumCornerDisplacement >= 0 && maximumCornerDisplacement <= 1,
        ),
        assert(maximumCoverageDelta >= 0 && maximumCoverageDelta <= 1);

  final int requiredStableFrames;
  final double minimumSharpnessScore;
  final double minimumDetectionConfidence;

  /// Maximum normalized movement of any corresponding card corner between
  /// adjacent accepted frames.
  final double maximumCornerDisplacement;

  /// Maximum absolute change in detected card coverage between adjacent
  /// accepted frames.
  final double maximumCoverageDelta;
}

/// Result of adding one frame to [CardCaptureStabilityTracker].
class CardCaptureStabilitySnapshot {
  const CardCaptureStabilitySnapshot({
    required this.stableFrameCount,
    required this.requiredStableFrames,
    required this.maxCornerDisplacement,
    required this.coverageDelta,
    required this.issue,
  });

  final int stableFrameCount;
  final int requiredStableFrames;
  final double maxCornerDisplacement;
  final double coverageDelta;
  final CardCaptureStabilityIssue? issue;

  bool get isStable =>
      issue == null && stableFrameCount >= requiredStableFrames;

  double get progress =>
      (stableFrameCount / requiredStableFrames).clamp(0.0, 1.0).toDouble();
}

/// Tracks whether a detected card remains sharp and spatially stable over
/// consecutive frames.
///
/// The tracker is deterministic and UI/camera-plugin agnostic. It does not
/// trigger capture. SC-04 can consume [CardCaptureStabilitySnapshot.isStable]
/// as one input to a separate auto-capture policy.
class CardCaptureStabilityTracker {
  CardCaptureStabilityTracker({
    this.config = const CardCaptureStabilityConfig(),
  });

  final CardCaptureStabilityConfig config;

  CardScanDetection? _previousDetection;
  double? _previousCoverage;
  int _stableFrameCount = 0;

  int get stableFrameCount => _stableFrameCount;

  void reset() {
    _previousDetection = null;
    _previousCoverage = null;
    _stableFrameCount = 0;
  }

  CardCaptureStabilitySnapshot addSample({
    required CardCaptureQualityAssessment assessment,
    required CardScanDetection? detection,
  }) {
    if (assessment.analysis.blur.score < config.minimumSharpnessScore) {
      reset();
      return _snapshot(issue: CardCaptureStabilityIssue.blurry);
    }

    if (detection == null) {
      reset();
      return _snapshot(issue: CardCaptureStabilityIssue.detectionMissing);
    }

    if (detection.confidence < config.minimumDetectionConfidence) {
      reset();
      return _snapshot(issue: CardCaptureStabilityIssue.lowDetectionConfidence);
    }

    final previousDetection = _previousDetection;
    final previousCoverage = _previousCoverage;
    final coverage = assessment.analysis.cardCoverage;

    if (previousDetection == null || previousCoverage == null) {
      _previousDetection = detection;
      _previousCoverage = coverage;
      _stableFrameCount = 1;
      return _snapshot();
    }

    final maxCornerDisplacement = _maxCornerDisplacement(
      previousDetection.quad,
      detection.quad,
    );
    final coverageDelta = (coverage - previousCoverage).abs();
    final moved =
        maxCornerDisplacement > config.maximumCornerDisplacement ||
            coverageDelta > config.maximumCoverageDelta;

    _previousDetection = detection;
    _previousCoverage = coverage;

    if (moved) {
      _stableFrameCount = 1;
      return _snapshot(
        issue: CardCaptureStabilityIssue.moved,
        maxCornerDisplacement: maxCornerDisplacement,
        coverageDelta: coverageDelta,
      );
    }

    _stableFrameCount += 1;
    return _snapshot(
      maxCornerDisplacement: maxCornerDisplacement,
      coverageDelta: coverageDelta,
    );
  }

  CardCaptureStabilitySnapshot _snapshot({
    CardCaptureStabilityIssue? issue,
    double maxCornerDisplacement = 0,
    double coverageDelta = 0,
  }) {
    return CardCaptureStabilitySnapshot(
      stableFrameCount: _stableFrameCount,
      requiredStableFrames: config.requiredStableFrames,
      maxCornerDisplacement: maxCornerDisplacement,
      coverageDelta: coverageDelta,
      issue: issue,
    );
  }

  double _maxCornerDisplacement(ProcessorQuad previous, ProcessorQuad current) {
    final previousPoints = _quadPoints(previous);
    final currentPoints = _quadPoints(current);

    var bestMaximumSquared = double.infinity;
    for (var shift = 0; shift < currentPoints.length; shift += 1) {
      var maximumSquared = 0.0;
      for (var index = 0; index < previousPoints.length; index += 1) {
        final currentIndex = (index + shift) % currentPoints.length;
        final dx = currentPoints[currentIndex].x - previousPoints[index].x;
        final dy = currentPoints[currentIndex].y - previousPoints[index].y;
        final squared = dx * dx + dy * dy;
        if (squared > maximumSquared) maximumSquared = squared;
      }
      if (maximumSquared < bestMaximumSquared) {
        bestMaximumSquared = maximumSquared;
      }
    }

    return math.sqrt(bestMaximumSquared);
  }

  List<ProcessorPoint> _quadPoints(ProcessorQuad quad) => <ProcessorPoint>[
        quad.topLeft,
        quad.topRight,
        quad.bottomRight,
        quad.bottomLeft,
      ];
}
