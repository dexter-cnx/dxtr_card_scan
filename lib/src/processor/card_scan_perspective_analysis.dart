import 'dart:math' as math;

import 'card_scan_detection.dart';
import 'card_scan_processor_options.dart';

/// Advisory perspective/alignment measurements derived from a detected quad.
///
/// These values are geometry-only and require no additional native image pass.
/// They are intentionally measurement-only until physical calibration defines
/// production thresholds.
class CardScanPerspectiveAnalysis {
  const CardScanPerspectiveAnalysis({
    required this.perspectiveScore,
    required this.alignmentScore,
    required this.oppositeEdgeBalance,
    required this.parallelismScore,
  });

  /// Overall perspective quality in `[0, 1]`; higher is less distorted.
  final double perspectiveScore;

  /// Existing detector center-alignment score in `[0, 1]`.
  final double alignmentScore;

  /// Similarity of opposite edge lengths in `[0, 1]`.
  final double oppositeEdgeBalance;

  /// Similarity of opposite edge directions in `[0, 1]`.
  final double parallelismScore;

  factory CardScanPerspectiveAnalysis.fromDetection(CardScanDetection detection) {
    final q = detection.quad;
    final top = _vector(q.topLeft, q.topRight);
    final right = _vector(q.topRight, q.bottomRight);
    final bottom = _vector(q.bottomLeft, q.bottomRight);
    final left = _vector(q.topLeft, q.bottomLeft);

    final horizontalBalance = _ratioSimilarity(top.length, bottom.length);
    final verticalBalance = _ratioSimilarity(left.length, right.length);
    final oppositeEdgeBalance = math.min(horizontalBalance, verticalBalance);

    final horizontalParallel = _directionSimilarity(top, bottom);
    final verticalParallel = _directionSimilarity(left, right);
    final parallelismScore = math.min(horizontalParallel, verticalParallel);

    final perspectiveScore = math
        .min(oppositeEdgeBalance, parallelismScore)
        .clamp(0.0, 1.0)
        .toDouble();

    return CardScanPerspectiveAnalysis(
      perspectiveScore: perspectiveScore,
      alignmentScore: detection.score.alignment.clamp(0.0, 1.0).toDouble(),
      oppositeEdgeBalance: oppositeEdgeBalance,
      parallelismScore: parallelismScore,
    );
  }
}

({double dx, double dy, double length}) _vector(
  ProcessorPoint a,
  ProcessorPoint b,
) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  return (dx: dx, dy: dy, length: math.sqrt(dx * dx + dy * dy));
}

double _ratioSimilarity(double a, double b) {
  final maxValue = math.max(a.abs(), b.abs());
  if (maxValue <= 1e-9) return 0;
  return (math.min(a.abs(), b.abs()) / maxValue).clamp(0.0, 1.0).toDouble();
}

double _directionSimilarity(
  ({double dx, double dy, double length}) a,
  ({double dx, double dy, double length}) b,
) {
  if (a.length <= 1e-9 || b.length <= 1e-9) return 0;
  final cosine = ((a.dx * b.dx + a.dy * b.dy) / (a.length * b.length))
      .abs()
      .clamp(0.0, 1.0)
      .toDouble();
  return cosine;
}
