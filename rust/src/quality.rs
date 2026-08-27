use image::{imageops::FilterType, DynamicImage, GrayImage, RgbImage};
use serde::Serialize;

use crate::{
    contrast_region::detect_card_quad_with_contrast_fallback,
    detection::{DetectionOptions, DetectionResult, Point},
};

const ANALYSIS_MAX_DIMENSION: u32 = 960;
const DARK_LUMA_THRESHOLD: u8 = 16;
const BRIGHT_LUMA_THRESHOLD: u8 = 239;
const GLARE_CHANNEL_THRESHOLD: u8 = 245;
const GLARE_TILE_SIZE: u32 = 32;
const SHARPNESS_NORMALIZATION: f32 = 400.0;

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub struct BlurMeasurement {
    pub laplacian_variance: f32,
    pub score: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub struct ExposureMeasurement {
    pub mean_luma: f32,
    pub dark_fraction: f32,
    pub bright_fraction: f32,
    pub score: f32,
}

/// Advisory specular-highlight measurement.
///
/// `specular_fraction` measures near-white neutral pixels across the frame,
/// while `peak_tile_fraction` captures localized hotspots. `score` is a
/// normalized glare-likelihood signal, not a calibrated production threshold.
#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub struct GlareMeasurement {
    pub specular_fraction: f32,
    pub peak_tile_fraction: f32,
    pub score: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub struct QualityAnalysis {
    pub blur: BlurMeasurement,
    pub exposure: ExposureMeasurement,
    pub glare: GlareMeasurement,
    pub card_coverage: f32,
    pub detection_confidence: f32,
    pub detection: Option<DetectionResult>,
}

pub fn analyze_quality(image: &DynamicImage) -> QualityAnalysis {
    let working = resize_for_analysis(image);
    let gray = working.to_luma8();
    let rgb = working.to_rgb8();
    let blur = measure_blur(&gray);
    let exposure = measure_exposure(&gray);
    let glare = measure_glare(&rgb);
    let detection = detect_card_quad_with_contrast_fallback(&working, DetectionOptions::default());

    QualityAnalysis {
        blur,
        exposure,
        glare,
        card_coverage: detection.as_ref().map(card_coverage).unwrap_or(0.0),
        detection_confidence: detection
            .as_ref()
            .map(|result| result.score.total.clamp(0.0, 1.0))
            .unwrap_or(0.0),
        detection,
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
    let count = (gray.width() as usize).saturating_mul(gray.height() as usize);
    if count == 0 {
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

fn measure_glare(rgb: &RgbImage) -> GlareMeasurement {
    let count = (rgb.width() as usize).saturating_mul(rgb.height() as usize);
    if count == 0 {
        return GlareMeasurement {
            specular_fraction: 0.0,
            peak_tile_fraction: 0.0,
            score: 0.0,
        };
    }

    let tiles_x = rgb.width().div_ceil(GLARE_TILE_SIZE).max(1);
    let tiles_y = rgb.height().div_ceil(GLARE_TILE_SIZE).max(1);
    let mut tile_specular = vec![0u32; (tiles_x * tiles_y) as usize];
    let mut specular = 0usize;

    for (x, y, pixel) in rgb.enumerate_pixels() {
        let [r, g, b] = pixel.0;
        if r >= GLARE_CHANNEL_THRESHOLD
            && g >= GLARE_CHANNEL_THRESHOLD
            && b >= GLARE_CHANNEL_THRESHOLD
        {
            specular += 1;
            let tile_x = x / GLARE_TILE_SIZE;
            let tile_y = y / GLARE_TILE_SIZE;
            tile_specular[(tile_y * tiles_x + tile_x) as usize] += 1;
        }
    }

    let specular_fraction = specular as f32 / count as f32;
    let mut peak_tile_fraction = 0.0f32;
    for tile_y in 0..tiles_y {
        for tile_x in 0..tiles_x {
            let left = tile_x * GLARE_TILE_SIZE;
            let top = tile_y * GLARE_TILE_SIZE;
            let tile_width = GLARE_TILE_SIZE.min(rgb.width() - left);
            let tile_height = GLARE_TILE_SIZE.min(rgb.height() - top);
            let tile_count = (tile_width * tile_height).max(1);
            let tile_index = (tile_y * tiles_x + tile_x) as usize;
            let fraction = tile_specular[tile_index] as f32 / tile_count as f32;
            peak_tile_fraction = peak_tile_fraction.max(fraction);
        }
    }

    // Keep this deliberately advisory. The normalization constants only make
    // the signal convenient to consume; physical evidence must calibrate any
    // future acceptance threshold.
    let global_signal = (specular_fraction / 0.08).clamp(0.0, 1.0);
    let hotspot_signal = (peak_tile_fraction / 0.35).clamp(0.0, 1.0);
    let score = global_signal.max(hotspot_signal);

    GlareMeasurement {
        specular_fraction,
        peak_tile_fraction,
        score,
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
    use image::{DynamicImage, GrayImage, Luma, Rgb, RgbImage};

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
    fn localized_neutral_highlight_scores_as_glare() {
        let clean = RgbImage::from_pixel(128, 96, Rgb([160, 160, 160]));
        let mut glare = clean.clone();
        for y in 20..52 {
            for x in 36..68 {
                glare.put_pixel(x, y, Rgb([255, 255, 255]));
            }
        }

        let clean_measurement = measure_glare(&clean);
        let glare_measurement = measure_glare(&glare);
        assert_eq!(clean_measurement.score, 0.0);
        assert!(glare_measurement.specular_fraction > 0.0);
        assert!(glare_measurement.peak_tile_fraction > 0.0);
        assert!(glare_measurement.score > clean_measurement.score);
    }

    #[test]
    fn colored_bright_area_is_not_specular_glare() {
        let image = RgbImage::from_pixel(64, 64, Rgb([255, 220, 220]));
        let measurement = measure_glare(&image);
        assert_eq!(measurement.specular_fraction, 0.0);
        assert_eq!(measurement.score, 0.0);
    }

    #[test]
    fn analysis_values_are_normalized() {
        let image = DynamicImage::ImageLuma8(GrayImage::from_pixel(160, 100, Luma([128])));
        let result = analyze_quality(&image);
        assert!((0.0..=1.0).contains(&result.blur.score));
        assert!((0.0..=1.0).contains(&result.exposure.score));
        assert!((0.0..=1.0).contains(&result.glare.score));
        assert!((0.0..=1.0).contains(&result.card_coverage));
        assert!((0.0..=1.0).contains(&result.detection_confidence));
    }
}
