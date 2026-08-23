use image::{imageops::FilterType, DynamicImage, GrayImage};
use serde::Serialize;

use crate::detection::{detect_card_quad, DetectionOptions, DetectionResult, Point};

const ANALYSIS_MAX_DIMENSION: u32 = 960;
const DARK_LUMA_THRESHOLD: u8 = 16;
const BRIGHT_LUMA_THRESHOLD: u8 = 239;
const SHARPNESS_NORMALIZATION: f32 = 400.0;

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub struct BlurMeasurement {
    /// Variance of the 4-neighbour Laplacian. Higher values indicate more edge detail.
    pub laplacian_variance: f32,
    /// Normalized [0, 1] sharpness score derived from Laplacian variance.
    pub score: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub struct ExposureMeasurement {
    /// Mean luminance normalized to [0, 1].
    pub mean_luma: f32,
    /// Fraction of pixels close to black.
    pub dark_fraction: f32,
    /// Fraction of pixels close to white.
    pub bright_fraction: f32,
    /// Normalized [0, 1] exposure-quality measurement.
    pub score: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub struct QualityAnalysis {
    pub blur: BlurMeasurement,
    pub exposure: ExposureMeasurement,
    /// Fraction of the analysis image covered by the detected card quadrilateral.
    pub card_coverage: f32,
    /// Total confidence reported by the deterministic card detector.
    pub detection_confidence: f32,
}

pub fn analyze_quality(image: &DynamicImage) -> QualityAnalysis {
    let working = resize_for_analysis(image);
    let gray = working.to_luma8();
    let blur = measure_blur(&gray);
    let exposure = measure_exposure(&gray);
    let detection = detect_card_quad(&working, DetectionOptions::default());

    QualityAnalysis {
        blur,
        exposure,
        card_coverage: detection.as_ref().map(card_coverage).unwrap_or(0.0),
        detection_confidence: detection
            .as_ref()
            .map(|result| result.score.total.clamp(0.0, 1.0))
            .unwrap_or(0.0),
    }
}

fn resize_for_analysis(image: &DynamicImage) -> DynamicImage {
    let width = image.width();
    let height = image.height();
    let longest = width.max(height);
    if longest <= ANALYSIS_MAX_DIMENSION {
        return image.clone();
    }

    let scale = ANALYSIS_MAX_DIMENSION as f64 / longest as f64;
    let resized_width = ((width as f64 * scale).round() as u32).max(1);
    let resized_height = ((height as f64 * scale).round() as u32).max(1);
    image.resize(resized_width, resized_height, FilterType::Triangle)
}

fn measure_blur(gray: &GrayImage) -> BlurMeasurement {
    if gray.width() < 3 || gray.height() < 3 {
        return BlurMeasurement {
            laplacian_variance: 0.0,
            score: 0.0,
        };
    }

    let mut sum = 0.0f64;
    let mut sum_sq = 0.0f64;
    let mut count = 0usize;

    for y in 1..gray.height() - 1 {
        for x in 1..gray.width() - 1 {
            let center = gray.get_pixel(x, y).0[0] as f32;
            let left = gray.get_pixel(x - 1, y).0[0] as f32;
            let right = gray.get_pixel(x + 1, y).0[0] as f32;
            let top = gray.get_pixel(x, y - 1).0[0] as f32;
            let bottom = gray.get_pixel(x, y + 1).0[0] as f32;
            let value = 4.0 * center - left - right - top - bottom;
            sum += value as f64;
            sum_sq += (value * value) as f64;
            count += 1;
        }
    }

    if count == 0 {
        return BlurMeasurement {
            laplacian_variance: 0.0,
            score: 0.0,
        };
    }

    let mean = sum / count as f64;
    let variance = (sum_sq / count as f64 - mean * mean).max(0.0) as f32;
    let score = (1.0 - (-variance / SHARPNESS_NORMALIZATION).exp()).clamp(0.0, 1.0);

    BlurMeasurement {
        laplacian_variance: variance,
        score,
    }
}

fn measure_exposure(gray: &GrayImage) -> ExposureMeasurement {
    if gray.is_empty() {
        return ExposureMeasurement {
            mean_luma: 0.0,
            dark_fraction: 0.0,
            bright_fraction: 0.0,
            score: 0.0,
        };
    }

    let mut sum = 0u64;
    let mut dark = 0usize;
    let mut bright = 0usize;
    let count = gray.len();

    for pixel in gray.pixels() {
        let value = pixel.0[0];
        sum += value as u64;
        if value <= DARK_LUMA_THRESHOLD {
            dark += 1;
        }
        if value >= BRIGHT_LUMA_THRESHOLD {
            bright += 1;
        }
    }

    let mean_luma = (sum as f32 / count as f32 / 255.0).clamp(0.0, 1.0);
    let dark_fraction = dark as f32 / count as f32;
    let bright_fraction = bright as f32 / count as f32;
    let midpoint_score = (1.0 - ((mean_luma - 0.5).abs() / 0.5)).clamp(0.0, 1.0);
    let clipping_score = (1.0 - dark_fraction - bright_fraction).clamp(0.0, 1.0);

    ExposureMeasurement {
        mean_luma,
        dark_fraction,
        bright_fraction,
        score: midpoint_score * clipping_score,
    }
}

fn card_coverage(result: &DetectionResult) -> f32 {
    polygon_area(result.quad.corners).clamp(0.0, 1.0)
}

fn polygon_area(points: [Point; 4]) -> f32 {
    let mut sum = 0.0f32;
    for index in 0..4 {
        let a = points[index];
        let b = points[(index + 1) % 4];
        sum += a.x * b.y - b.x * a.y;
    }
    sum.abs() * 0.5
}

#[cfg(test)]
mod tests {
    use image::{DynamicImage, GrayImage, Luma};

    use super::*;

    #[test]
    fn sharp_pattern_scores_higher_than_flat_image() {
        let flat = GrayImage::from_pixel(120, 80, Luma([128]));
        let mut pattern = GrayImage::from_pixel(120, 80, Luma([32]));
        for y in 0..80 {
            for x in 0..120 {
                if (x / 4 + y / 4) % 2 == 0 {
                    pattern.put_pixel(x, y, Luma([224]));
                }
            }
        }

        let flat_measurement = measure_blur(&flat);
        let pattern_measurement = measure_blur(&pattern);
        assert!(pattern_measurement.score > flat_measurement.score);
        assert!(pattern_measurement.laplacian_variance > flat_measurement.laplacian_variance);
    }

    #[test]
    fn middle_gray_exposure_scores_higher_than_clipped_images() {
        let middle = GrayImage::from_pixel(100, 100, Luma([128]));
        let dark = GrayImage::from_pixel(100, 100, Luma([0]));
        let bright = GrayImage::from_pixel(100, 100, Luma([255]));

        let middle_measurement = measure_exposure(&middle);
        assert!(middle_measurement.score > measure_exposure(&dark).score);
        assert!(middle_measurement.score > measure_exposure(&bright).score);
    }

    #[test]
    fn analysis_values_are_normalized() {
        let image = DynamicImage::ImageLuma8(GrayImage::from_pixel(160, 100, Luma([128])));
        let result = analyze_quality(&image);
        assert!((0.0..=1.0).contains(&result.blur.score));
        assert!((0.0..=1.0).contains(&result.exposure.score));
        assert!((0.0..=1.0).contains(&result.card_coverage));
        assert!((0.0..=1.0).contains(&result.detection_confidence));
    }
}