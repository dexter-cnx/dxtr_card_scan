import 'card_scan_detection.dart';

class CardScanBlurQuality {
  const CardScanBlurQuality({
    required this.laplacianVariance,
    required this.score,
  });

  final double laplacianVariance;
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

/// Advisory specular-highlight measurement for glare detection.
class CardScanGlareQuality {
  const CardScanGlareQuality({
    required this.specularFraction,
    required this.peakTileFraction,
    required this.score,
  });

  const CardScanGlareQuality.none()
      : specularFraction = 0,
        peakTileFraction = 0,
        score = 0;

  final double specularFraction;
  final double peakTileFraction;

  /// Normalized glare-likelihood signal. This is not a calibrated acceptance
  /// threshold; physical evidence must define any production gate.
  final double score;

  factory CardScanGlareQuality.fromJson(Map<String, Object?> json) {
    return CardScanGlareQuality(
      specularFraction: (json['specular_fraction'] as num).toDouble(),
      peakTileFraction: (json['peak_tile_fraction'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
    );
  }
}

/// Measurement-only image quality analysis.
class CardScanQualityAnalysis {
  const CardScanQualityAnalysis({
    required this.blur,
    required this.exposure,
    this.glare = const CardScanGlareQuality.none(),
    required this.cardCoverage,
    required this.detectionConfidence,
  });

  final CardScanBlurQuality blur;
  final CardScanExposureQuality exposure;
  final CardScanGlareQuality glare;
  final double cardCoverage;
  final double detectionConfidence;

  factory CardScanQualityAnalysis.fromJson(Map<String, Object?> json) {
    final rawGlare = json['glare'];
    return CardScanQualityAnalysis(
      blur: CardScanBlurQuality.fromJson(
        (json['blur'] as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      exposure: CardScanExposureQuality.fromJson(
        (json['exposure'] as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      glare: rawGlare == null
          ? const CardScanGlareQuality.none()
          : CardScanGlareQuality.fromJson(
              (rawGlare as Map<Object?, Object?>).cast<String, Object?>(),
            ),
      cardCoverage: (json['card_coverage'] as num).toDouble(),
      detectionConfidence: (json['detection_confidence'] as num).toDouble(),
    );
  }
}

/// Quality and detection produced by one native analysis pass.
class CardScanFrameAnalysis {
  const CardScanFrameAnalysis({
    required this.quality,
    required this.detection,
  });

  final CardScanQualityAnalysis quality;
  final CardScanDetection? detection;

  factory CardScanFrameAnalysis.fromJson(Map<String, Object?> json) {
    final rawDetection = json['detection'];
    return CardScanFrameAnalysis(
      quality: CardScanQualityAnalysis.fromJson(json),
      detection: rawDetection == null
          ? null
          : CardScanDetection.fromJson(
              (rawDetection as Map<Object?, Object?>).cast<String, Object?>(),
            ),
    );
  }
}

enum CardCaptureQualityIssue {
  blurry,
  tooDark,
  tooBright,
  cardTooSmall,
  lowDetectionConfidence,
}

class CardCaptureQualityThresholds {
  const CardCaptureQualityThresholds({
    this.minimumSharpnessScore = .55,
    this.minimumMeanLuma = .25,
    this.maximumMeanLuma = .80,
    this.maximumDarkFraction = .30,
    this.maximumBrightFraction = .20,
    this.minimumCardCoverage = .32,
    this.minimumDetectionConfidence = .60,
  })  : assert(minimumSharpnessScore >= 0 && minimumSharpnessScore <= 1),
        assert(minimumMeanLuma >= 0 && minimumMeanLuma <= 1),
        assert(maximumMeanLuma >= 0 && maximumMeanLuma <= 1),
        assert(minimumMeanLuma <= maximumMeanLuma),
        assert(maximumDarkFraction >= 0 && maximumDarkFraction <= 1),
        assert(maximumBrightFraction >= 0 && maximumBrightFraction <= 1),
        assert(minimumCardCoverage >= 0 && minimumCardCoverage <= 1),
        assert(
          minimumDetectionConfidence >= 0 && minimumDetectionConfidence <= 1,
        );

  final double minimumSharpnessScore;
  final double minimumMeanLuma;
  final double maximumMeanLuma;
  final double maximumDarkFraction;
  final double maximumBrightFraction;
  final double minimumCardCoverage;
  final double minimumDetectionConfidence;
}

class CardCaptureQualityAssessment {
  const CardCaptureQualityAssessment({
    required this.analysis,
    required this.issues,
    required this.score,
  });

  final CardScanQualityAnalysis analysis;
  final Set<CardCaptureQualityIssue> issues;
  final double score;

  bool get hasIssues => issues.isNotEmpty;
  CardCaptureQualityIssue? get primaryIssue =>
      issues.isEmpty ? null : issues.first;

  factory CardCaptureQualityAssessment.fromAnalysis(
    CardScanQualityAnalysis analysis, {
    CardCaptureQualityThresholds thresholds =
        const CardCaptureQualityThresholds(),
  }) {
    final issues = <CardCaptureQualityIssue>{};
    final detectionReliable =
        analysis.detectionConfidence >= thresholds.minimumDetectionConfidence;

    if (analysis.blur.score < thresholds.minimumSharpnessScore) {
      issues.add(CardCaptureQualityIssue.blurry);
    }
    if (analysis.exposure.meanLuma < thresholds.minimumMeanLuma ||
        analysis.exposure.darkFraction > thresholds.maximumDarkFraction) {
      issues.add(CardCaptureQualityIssue.tooDark);
    }
    if (analysis.exposure.meanLuma > thresholds.maximumMeanLuma ||
        analysis.exposure.brightFraction > thresholds.maximumBrightFraction) {
      issues.add(CardCaptureQualityIssue.tooBright);
    }
    if (!detectionReliable) {
      issues.add(CardCaptureQualityIssue.lowDetectionConfidence);
    } else if (analysis.cardCoverage < thresholds.minimumCardCoverage) {
      issues.add(CardCaptureQualityIssue.cardTooSmall);
    }

    final exposurePenalty =
        (1 - analysis.exposure.darkFraction - analysis.exposure.brightFraction)
            .clamp(0.0, 1.0)
            .toDouble();
    final score = <double>[
      analysis.blur.score.clamp(0.0, 1.0).toDouble(),
      analysis.exposure.score.clamp(0.0, 1.0).toDouble(),
      exposurePenalty,
      analysis.cardCoverage.clamp(0.0, 1.0).toDouble(),
      analysis.detectionConfidence.clamp(0.0, 1.0).toDouble(),
    ].reduce((value, next) => value < next ? value : next);

    return CardCaptureQualityAssessment(
      analysis: analysis,
      issues: Set.unmodifiable(issues),
      score: score,
    );
  }
}
