import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../processor/card_scan_detection.dart';
import '../processor/card_scan_processor_options.dart';

/// Geometry-only confidence attached to one detected corner.
class CardCornerConfidence {
  const CardCornerConfidence({
    required this.point,
    required this.score,
  });

  final ProcessorPoint point;
  final double score;
}

/// Advisory corner feedback derived from an existing detection result.
///
/// No extra image-analysis pass is performed. Each corner score combines the
/// detector's edge-strength confidence with how close the adjacent edges are to
/// a right angle in pixel-space geometry.
class CardCornerFeedback {
  const CardCornerFeedback({
    required this.corners,
    required this.overallConfidence,
  });

  final List<CardCornerConfidence> corners;
  final double overallConfidence;

  factory CardCornerFeedback.fromDetection(
    CardScanDetection detection, {
    required double imageAspectRatio,
  }) {
    assert(imageAspectRatio > 0);
    final q = detection.quad;
    final points = <ProcessorPoint>[
      q.topLeft,
      q.topRight,
      q.bottomRight,
      q.bottomLeft,
    ];
    final edgeStrength = detection.score.edgeStrength.clamp(0.0, 1.0).toDouble();
    final corners = <CardCornerConfidence>[];

    for (var index = 0; index < points.length; index++) {
      final previous = points[(index + points.length - 1) % points.length];
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final incoming = _vector(current, previous, imageAspectRatio);
      final outgoing = _vector(current, next, imageAspectRatio);
      final orthogonality = _orthogonality(incoming, outgoing);
      corners.add(
        CardCornerConfidence(
          point: current,
          score: (orthogonality * edgeStrength).clamp(0.0, 1.0).toDouble(),
        ),
      );
    }

    final overall = corners
        .map((corner) => corner.score)
        .reduce(math.min)
        .clamp(0.0, 1.0)
        .toDouble();
    return CardCornerFeedback(
      corners: List.unmodifiable(corners),
      overallConfidence: overall,
    );
  }
}

/// Paints detected-corner feedback inside the capture-frame rectangle.
///
/// Detection coordinates are expected to be normalized to the analyzed ROI,
/// so they can be mapped directly into [frameRect].
class CardCornerFeedbackOverlay extends StatelessWidget {
  const CardCornerFeedbackOverlay({
    required this.feedback,
    required this.frameRect,
    this.minimumVisibleConfidence = 0,
    this.lineWidth = 2,
    this.cornerRadius = 6,
    super.key,
  })  : assert(minimumVisibleConfidence >= 0 && minimumVisibleConfidence <= 1),
        assert(lineWidth > 0),
        assert(cornerRadius > 0);

  final CardCornerFeedback feedback;
  final Rect frameRect;
  final double minimumVisibleConfidence;
  final double lineWidth;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CardCornerFeedbackPainter(
          feedback: feedback,
          frameRect: frameRect,
          minimumVisibleConfidence: minimumVisibleConfidence,
          lineWidth: lineWidth,
          cornerRadius: cornerRadius,
          colorScheme: Theme.of(context).colorScheme,
        ),
      ),
    );
  }
}

class _CardCornerFeedbackPainter extends CustomPainter {
  const _CardCornerFeedbackPainter({
    required this.feedback,
    required this.frameRect,
    required this.minimumVisibleConfidence,
    required this.lineWidth,
    required this.cornerRadius,
    required this.colorScheme,
  });

  final CardCornerFeedback feedback;
  final Rect frameRect;
  final double minimumVisibleConfidence;
  final double lineWidth;
  final double cornerRadius;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (feedback.corners.length != 4 || frameRect.isEmpty) return;
    final points = feedback.corners
        .map((corner) => _mapPoint(corner.point, frameRect))
        .toList(growable: false);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = _confidenceColor(feedback.overallConfidence)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth,
    );

    for (var index = 0; index < points.length; index++) {
      final confidence = feedback.corners[index].score;
      if (confidence < minimumVisibleConfidence) continue;
      canvas.drawCircle(
        points[index],
        cornerRadius,
        Paint()
          ..color = _confidenceColor(confidence)
          ..style = PaintingStyle.fill,
      );
    }
  }

  Color _confidenceColor(double confidence) {
    final value = confidence.clamp(0.0, 1.0).toDouble();
    if (value >= .75) return colorScheme.primary;
    if (value >= .45) return colorScheme.tertiary;
    return colorScheme.error;
  }

  @override
  bool shouldRepaint(_CardCornerFeedbackPainter oldDelegate) =>
      feedback != oldDelegate.feedback ||
      frameRect != oldDelegate.frameRect ||
      minimumVisibleConfidence != oldDelegate.minimumVisibleConfidence ||
      lineWidth != oldDelegate.lineWidth ||
      cornerRadius != oldDelegate.cornerRadius ||
      colorScheme != oldDelegate.colorScheme;
}

Offset _mapPoint(ProcessorPoint point, Rect frameRect) => Offset(
      frameRect.left + point.x.clamp(0.0, 1.0) * frameRect.width,
      frameRect.top + point.y.clamp(0.0, 1.0) * frameRect.height,
    );

({double dx, double dy, double length}) _vector(
  ProcessorPoint from,
  ProcessorPoint to,
  double imageAspectRatio,
) {
  final dx = (to.x - from.x) * imageAspectRatio;
  final dy = to.y - from.y;
  return (dx: dx, dy: dy, length: math.sqrt(dx * dx + dy * dy));
}

double _orthogonality(
  ({double dx, double dy, double length}) a,
  ({double dx, double dy, double length}) b,
) {
  if (a.length <= 1e-9 || b.length <= 1e-9) return 0;
  final cosine = ((a.dx * b.dx + a.dy * b.dy) / (a.length * b.length))
      .abs()
      .clamp(0.0, 1.0)
      .toDouble();
  return (1 - cosine).clamp(0.0, 1.0).toDouble();
}
