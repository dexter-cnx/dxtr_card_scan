class CardScanBlurQuality {
  const CardScanBlurQuality({
    required this.laplacianVariance,
    required this.score,
  });

  final double laplacianVariance;

  /// Normalized [0, 1] sharpness measurement. Higher means more edge detail.
  final double score;

  factory CardScanBlurQuality.fromJson(Map<String, Object?> json) {
    return CardScanBlurQuality(
      laplacianVariance: (json['laplacian_variance'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
    );
  }
}

class CardScanExposureQuality {
  const CardScanExposureQuality({
    required this.meanLuma,
    required this.darkFraction,
    required this.brightFraction,
    required this.score,
  });

  final double meanLuma;
  final double darkFraction;
  final double brightFraction;

  /// Normalized [0, 1] exposure measurement.
  final double score;

  factory CardScanExposureQuality.fromJson(Map<String, Object?> json) {
    return CardScanExposureQuality(
      meanLuma: (json['mean_luma'] as num).toDouble(),
      darkFraction: (json['dark_fraction'] as num).toDouble(),
      brightFraction: (json['bright_fraction'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
    );
  }
}

/// Measurement-only image quality analysis.
///
/// These values intentionally do not imply pass/fail capture readiness. Apps
/// may observe them, collect calibration evidence, and define policy later.
class CardScanQualityAnalysis {
  const CardScanQualityAnalysis({
    required this.blur,
    required this.exposure,
    required this.cardCoverage,
    required this.detectionConfidence,
  });

  final CardScanBlurQuality blur;
  final CardScanExposureQuality exposure;

  /// Fraction [0, 1] of the analysis image covered by the detected card quad.
  final double cardCoverage;

  /// Deterministic card-detector confidence [0, 1].
  final double detectionConfidence;

  factory CardScanQualityAnalysis.fromJson(Map<String, Object?> json) {
    return CardScanQualityAnalysis(
      blur: CardScanBlurQuality.fromJson(
        (json['blur'] as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      exposure: CardScanExposureQuality.fromJson(
        (json['exposure'] as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      cardCoverage: (json['card_coverage'] as num).toDouble(),
      detectionConfidence: (json['detection_confidence'] as num).toDouble(),
    );
  }
}