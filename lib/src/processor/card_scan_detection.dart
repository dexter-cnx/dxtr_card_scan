import '../geometry/normalized_rect.dart';
import 'card_scan_processor_options.dart';

class CardScanDetectionScore {
  const CardScanDetectionScore({
    required this.total,
    required this.area,
    required this.rectangularity,
    required this.aspectRatio,
    required this.alignment,
    required this.edgeStrength,
  });

  final double total;
  final double area;
  final double rectangularity;
  final double aspectRatio;
  final double alignment;
  final double edgeStrength;
}

class CardScanDetection {
  const CardScanDetection({
    required this.quad,
    required this.score,
  });

  final ProcessorQuad quad;
  final CardScanDetectionScore score;

  double get confidence => score.total;

  NormalizedRect boundingRect({double padding = 0}) {
    assert(padding >= 0 && padding < 0.5);
    final points = <ProcessorPoint>[
      quad.topLeft,
      quad.topRight,
      quad.bottomRight,
      quad.bottomLeft,
    ];
    final minX = points.map((point) => point.x).reduce((a, b) => a < b ? a : b);
    final maxX = points.map((point) => point.x).reduce((a, b) => a > b ? a : b);
    final minY = points.map((point) => point.y).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((point) => point.y).reduce((a, b) => a > b ? a : b);

    return NormalizedRect(
      left: (minX - padding).clamp(0.0, 1.0).toDouble(),
      top: (minY - padding).clamp(0.0, 1.0).toDouble(),
      right: (maxX + padding).clamp(0.0, 1.0).toDouble(),
      bottom: (maxY + padding).clamp(0.0, 1.0).toDouble(),
    );
  }

  factory CardScanDetection.fromJson(Map<String, Object?> json) {
    final quadJson = json['quad']! as Map<String, Object?>;
    final corners =
        (quadJson['corners']! as List<Object?>).cast<Map<String, Object?>>();
    if (corners.length != 4) {
      throw const FormatException('card detection must contain four corners');
    }

    ProcessorPoint pointAt(int index) {
      final point = corners[index];
      return ProcessorPoint(
        (point['x']! as num).toDouble(),
        (point['y']! as num).toDouble(),
      );
    }

    final scoreJson = json['score']! as Map<String, Object?>;
    return CardScanDetection(
      quad: ProcessorQuad(
        topLeft: pointAt(0),
        topRight: pointAt(1),
        bottomRight: pointAt(2),
        bottomLeft: pointAt(3),
      ),
      score: CardScanDetectionScore(
        total: (scoreJson['total']! as num).toDouble(),
        area: (scoreJson['area']! as num).toDouble(),
        rectangularity: (scoreJson['rectangularity']! as num).toDouble(),
        aspectRatio: (scoreJson['aspect_ratio']! as num).toDouble(),
        alignment: (scoreJson['alignment']! as num).toDouble(),
        edgeStrength: (scoreJson['edge_strength']! as num).toDouble(),
      ),
    );
  }
}
