use std::collections::VecDeque;

use image::{imageops::FilterType, DynamicImage, RgbImage};

use crate::detection::{
    detect_card_quad, CandidateScore, DetectionOptions, DetectionResult, Point, Quad,
};

const GALLERY_DETECTION_MAX_DIMENSION: u32 = 640;
const MIN_COLOR_DISTANCE: f32 = 42.0;
const MIN_LUMA_DISTANCE: f32 = 20.0;
const MIN_COMPONENT_PIXELS: usize = 32;
const MAX_AREA_RATIO: f32 = 0.70;
const BORDER_MARGIN_RATIO: f32 = 0.01;
const STRONG_ASPECT_SCORE: f32 = 0.80;

/// Fast hybrid detector intended for Gallery initial-crop seeding.
///
/// Both edge and contrast-region candidates are evaluated on the same small
/// thumbnail. The more card-like result wins.
pub fn detect_card_quad_with_contrast_fallback(
    image: &DynamicImage,
    options: DetectionOptions,
) -> Option<DetectionResult> {
    let working = resize_for_gallery_detection(image);
    let edge = detect_card_quad(&working, options);
    let contrast = detect_contrast_region(&working, options);
    choose_candidate(edge, contrast)
}

fn resize_for_gallery_detection(image: &DynamicImage) -> DynamicImage {
    let width = image.width();
    let height = image.height();
    let longest = width.max(height);
    if longest <= GALLERY_DETECTION_MAX_DIMENSION {
        return image.clone();
    }

    let scale = GALLERY_DETECTION_MAX_DIMENSION as f64 / longest as f64;
    let resized_width = ((width as f64 * scale).round() as u32).max(1);
    let resized_height = ((height as f64 * scale).round() as u32).max(1);
    image.resize(resized_width, resized_height, FilterType::Triangle)
}

fn choose_candidate(
    edge: Option<DetectionResult>,
    contrast: Option<DetectionResult>,
) -> Option<DetectionResult> {
    match (edge, contrast) {
        (None, None) => None,
        (Some(candidate), None) | (None, Some(candidate)) => Some(candidate),
        (Some(edge), Some(contrast)) => {
            if edge.score.aspect_ratio < STRONG_ASPECT_SCORE
                && contrast.score.aspect_ratio >= STRONG_ASPECT_SCORE
            {
                return Some(contrast);
            }

            if candidate_quality(contrast.score) > candidate_quality(edge.score) {
                Some(contrast)
            } else {
                Some(edge)
            }
        }
    }
}

fn candidate_quality(score: CandidateScore) -> f32 {
    0.52 * score.aspect_ratio
        + 0.24 * score.rectangularity
        + 0.08 * score.area
        + 0.08 * score.alignment
        + 0.08 * score.edge_strength
}

#[derive(Clone, Copy)]
struct BackgroundStats {
    rgb: [f32; 3],
    rgb_std_dev: f32,
    luma: f32,
    luma_std_dev: f32,
}

/// Finds a card-like region whose color or luminance differs from the image
/// border. RGB distance is important for cases such as a cyan ID card on a
/// textured brown desk where grayscale contrast alone is weak.
pub fn detect_contrast_region(
    image: &DynamicImage,
    options: DetectionOptions,
) -> Option<DetectionResult> {
    let rgb = image.to_rgb8();
    let width = rgb.width();
    let height = rgb.height();
    if width < 16 || height < 16 {
        return None;
    }

    let background = border_statistics(&rgb);
    let color_threshold = (background.rgb_std_dev * 1.15).max(MIN_COLOR_DISTANCE);
    let luma_threshold = (background.luma_std_dev * 0.90).max(MIN_LUMA_DISTANCE);

    let mask = rgb
        .pixels()
        .map(|pixel| {
            color_distance(pixel.0, background.rgb) >= color_threshold
                || (pixel_luma(pixel.0) - background.luma).abs() >= luma_threshold
        })
        .collect::<Vec<_>>();
    let closed = dilate_mask(&mask, width, height, 1);

    connected_components(&closed, width, height)
        .into_iter()
        .filter_map(|component| candidate_from_component(&rgb, &component, options, background))
        .max_by(|a, b| candidate_quality(a.score).total_cmp(&candidate_quality(b.score)))
}

fn border_statistics(rgb: &RgbImage) -> BackgroundStats {
    let width = rgb.width();
    let height = rgb.height();
    let band_x = (width / 24).max(1);
    let band_y = (height / 24).max(1);
    let mut sum = [0.0f64; 3];
    let mut sum_sq = 0.0f64;
    let mut luma_sum = 0.0f64;
    let mut luma_sum_sq = 0.0f64;
    let mut samples = Vec::new();

    for y in 0..height {
        for x in 0..width {
            if x < band_x || x >= width - band_x || y < band_y || y >= height - band_y {
                let p = rgb.get_pixel(x, y).0;
                let channels = [p[0] as f64, p[1] as f64, p[2] as f64];
                for index in 0..3 {
                    sum[index] += channels[index];
                }
                let luma = pixel_luma(p) as f64;
                luma_sum += luma;
                luma_sum_sq += luma * luma;
                samples.push(p);
            }
        }
    }

    if samples.is_empty() {
        return BackgroundStats {
            rgb: [128.0; 3],
            rgb_std_dev: 0.0,
            luma: 128.0,
            luma_std_dev: 0.0,
        };
    }

    let count = samples.len() as f64;
    let mean = [
        (sum[0] / count) as f32,
        (sum[1] / count) as f32,
        (sum[2] / count) as f32,
    ];
    for p in &samples {
        let distance = color_distance(*p, mean) as f64;
        sum_sq += distance * distance;
    }
    let luma_mean = luma_sum / count;
    let luma_variance = (luma_sum_sq / count - luma_mean * luma_mean).max(0.0);

    BackgroundStats {
        rgb: mean,
        rgb_std_dev: (sum_sq / count).sqrt() as f32,
        luma: luma_mean as f32,
        luma_std_dev: luma_variance.sqrt() as f32,
    }
}

fn pixel_luma(pixel: [u8; 3]) -> f32 {
    0.2126 * pixel[0] as f32 + 0.7152 * pixel[1] as f32 + 0.0722 * pixel[2] as f32
}

fn color_distance(pixel: [u8; 3], mean: [f32; 3]) -> f32 {
    let dr = pixel[0] as f32 - mean[0];
    let dg = pixel[1] as f32 - mean[1];
    let db = pixel[2] as f32 - mean[2];
    (dr * dr + dg * dg + db * db).sqrt()
}

fn dilate_mask(mask: &[bool], width: u32, height: u32, radius: i32) -> Vec<bool> {
    let mut output = vec![false; mask.len()];
    for y in 0..height {
        for x in 0..width {
            let index = (y * width + x) as usize;
            if !mask[index] {
                continue;
            }
            for dy in -radius..=radius {
                for dx in -radius..=radius {
                    let nx = x as i32 + dx;
                    let ny = y as i32 + dy;
                    if nx >= 0 && ny >= 0 && nx < width as i32 && ny < height as i32 {
                        output[(ny as u32 * width + nx as u32) as usize] = true;
                    }
                }
            }
        }
    }
    output
}

fn connected_components(mask: &[bool], width: u32, height: u32) -> Vec<Vec<(u32, u32)>> {
    let mut visited = vec![false; mask.len()];
    let mut components = Vec::new();

    for y in 0..height {
        for x in 0..width {
            let index = (y * width + x) as usize;
            if !mask[index] || visited[index] {
                continue;
            }

            let mut queue = VecDeque::from([(x, y)]);
            let mut component = Vec::new();
            visited[index] = true;
            while let Some((cx, cy)) = queue.pop_front() {
                component.push((cx, cy));
                for dy in -1i32..=1 {
                    for dx in -1i32..=1 {
                        if dx == 0 && dy == 0 {
                            continue;
                        }
                        let nx = cx as i32 + dx;
                        let ny = cy as i32 + dy;
                        if nx < 0 || ny < 0 || nx >= width as i32 || ny >= height as i32 {
                            continue;
                        }
                        let nindex = ny as usize * width as usize + nx as usize;
                        if mask[nindex] && !visited[nindex] {
                            visited[nindex] = true;
                            queue.push_back((nx as u32, ny as u32));
                        }
                    }
                }
            }
            if component.len() >= MIN_COMPONENT_PIXELS {
                components.push(component);
            }
        }
    }
    components
}

fn candidate_from_component(
    rgb: &RgbImage,
    component: &[(u32, u32)],
    options: DetectionOptions,
    background: BackgroundStats,
) -> Option<DetectionResult> {
    let width = rgb.width();
    let height = rgb.height();
    let min_x = component.iter().map(|(x, _)| *x).min()?;
    let max_x = component.iter().map(|(x, _)| *x).max()?;
    let min_y = component.iter().map(|(_, y)| *y).min()?;
    let max_y = component.iter().map(|(_, y)| *y).max()?;

    if touches_border(min_x, min_y, max_x, max_y, width, height) {
        return None;
    }

    let box_width = (max_x - min_x + 1) as f32;
    let box_height = (max_y - min_y + 1) as f32;
    let area_ratio = box_width * box_height / (width as f32 * height as f32);
    if area_ratio < options.min_area_ratio.max(0.025) || area_ratio > MAX_AREA_RATIO {
        return None;
    }

    let aspect_score = options
        .expected_aspect_ratio
        .filter(|expected| expected.is_finite() && *expected > 0.0)
        .map(|expected| ratio_similarity(box_width / box_height, expected))
        .unwrap_or(1.0);
    if aspect_score < 0.72 {
        return None;
    }

    let fill_ratio = (component.len() as f32 / (box_width * box_height)).clamp(0.0, 1.0);
    if fill_ratio < 0.30 {
        return None;
    }

    let mut region_sum = [0.0f32; 3];
    for (x, y) in component {
        let p = rgb.get_pixel(*x, *y).0;
        region_sum[0] += p[0] as f32;
        region_sum[1] += p[1] as f32;
        region_sum[2] += p[2] as f32;
    }
    let count = component.len() as f32;
    let region_mean = [
        region_sum[0] / count,
        region_sum[1] / count,
        region_sum[2] / count,
    ];
    let dr = region_mean[0] - background.rgb[0];
    let dg = region_mean[1] - background.rgb[1];
    let db = region_mean[2] - background.rgb[2];
    let contrast_score = ((dr * dr + dg * dg + db * db).sqrt() / 120.0).clamp(0.0, 1.0);

    let center_x = (min_x + max_x) as f32 * 0.5;
    let center_y = (min_y + max_y) as f32 * 0.5;
    let dx = (center_x - width as f32 * 0.5).abs() / (width as f32 * 0.5);
    let dy = (center_y - height as f32 * 0.5).abs() / (height as f32 * 0.5);
    let alignment = (1.0 - (dx * dx + dy * dy).sqrt() / 2.0f32.sqrt()).clamp(0.0, 1.0);
    let area_score = area_plausibility(area_ratio);
    let total = candidate_quality(CandidateScore {
        total: 0.0,
        area: area_score,
        rectangularity: fill_ratio,
        aspect_ratio: aspect_score,
        alignment,
        edge_strength: contrast_score,
    });

    let denom_x = width.saturating_sub(1).max(1) as f32;
    let denom_y = height.saturating_sub(1).max(1) as f32;
    Some(DetectionResult {
        quad: Quad {
            corners: [
                Point { x: min_x as f32 / denom_x, y: min_y as f32 / denom_y },
                Point { x: max_x as f32 / denom_x, y: min_y as f32 / denom_y },
                Point { x: max_x as f32 / denom_x, y: max_y as f32 / denom_y },
                Point { x: min_x as f32 / denom_x, y: max_y as f32 / denom_y },
            ],
        },
        score: CandidateScore {
            total,
            area: area_score,
            rectangularity: fill_ratio,
            aspect_ratio: aspect_score,
            alignment,
            edge_strength: contrast_score,
        },
    })
}

fn touches_border(
    min_x: u32,
    min_y: u32,
    max_x: u32,
    max_y: u32,
    width: u32,
    height: u32,
) -> bool {
    let margin_x = ((width as f32 * BORDER_MARGIN_RATIO).round() as u32).max(1);
    let margin_y = ((height as f32 * BORDER_MARGIN_RATIO).round() as u32).max(1);
    min_x <= margin_x
        || min_y <= margin_y
        || max_x >= width.saturating_sub(1 + margin_x)
        || max_y >= height.saturating_sub(1 + margin_y)
}

fn ratio_similarity(actual: f32, expected: f32) -> f32 {
    if !actual.is_finite() || actual <= 0.0 {
        return 0.0;
    }
    let direct = (actual / expected).ln().abs();
    let rotated = (actual * expected).ln().abs();
    (-direct.min(rotated)).exp().clamp(0.0, 1.0)
}

fn area_plausibility(area_ratio: f32) -> f32 {
    if area_ratio <= 0.06 {
        (area_ratio / 0.06).clamp(0.0, 1.0)
    } else if area_ratio <= 0.42 {
        1.0
    } else {
        ((0.70 - area_ratio) / 0.28).clamp(0.0, 1.0)
    }
}

#[cfg(test)]
mod tests {
    use image::{DynamicImage, Rgb, RgbImage};

    use super::*;

    #[test]
    fn finds_cyan_card_on_brown_background() {
        let mut image = RgbImage::from_pixel(320, 240, Rgb([105, 62, 36]));
        for y in 100..170 {
            for x in 80..240 {
                image.put_pixel(x, y, Rgb([145, 218, 230]));
            }
        }

        let result = detect_contrast_region(
            &DynamicImage::ImageRgb8(image),
            DetectionOptions {
                expected_aspect_ratio: Some(160.0 / 70.0),
                min_area_ratio: 0.03,
                ..DetectionOptions::default()
            },
        )
        .expect("cyan card should be detected");

        assert!(result.score.aspect_ratio > 0.90);
        assert!(result.score.edge_strength > 0.50);
    }

    #[test]
    fn finds_bright_card_on_dark_background() {
        let mut image = RgbImage::from_pixel(300, 220, Rgb([48, 48, 48]));
        for y in 80..140 {
            for x in 75..225 {
                image.put_pixel(x, y, Rgb([210, 210, 210]));
            }
        }
        assert!(detect_contrast_region(
            &DynamicImage::ImageRgb8(image),
            DetectionOptions {
                expected_aspect_ratio: Some(150.0 / 60.0),
                min_area_ratio: 0.03,
                ..DetectionOptions::default()
            },
        )
        .is_some());
    }

    #[test]
    fn rejects_region_touching_image_border() {
        let mut image = RgbImage::from_pixel(240, 180, Rgb([48, 48, 48]));
        for y in 80..140 {
            for x in 0..150 {
                image.put_pixel(x, y, Rgb([190, 210, 220]));
            }
        }
        assert!(detect_contrast_region(
            &DynamicImage::ImageRgb8(image),
            DetectionOptions::default(),
        )
        .is_none());
    }
}
