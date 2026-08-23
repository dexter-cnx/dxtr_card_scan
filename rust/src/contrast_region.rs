use std::collections::VecDeque;

use image::{imageops::FilterType, DynamicImage, GrayImage};

use crate::detection::{
    detect_card_quad, CandidateScore, DetectionOptions, DetectionResult, Point, Quad,
};

const GALLERY_DETECTION_MAX_DIMENSION: u32 = 640;
const MIN_CONTRAST: f32 = 20.0;
const MIN_COMPONENT_PIXELS: usize = 32;
const MAX_AREA_RATIO: f32 = 0.70;
const BORDER_MARGIN_RATIO: f32 = 0.01;
const STRONG_ASPECT_SCORE: f32 = 0.80;

/// Fast hybrid detector intended for Gallery initial-crop seeding.
///
/// Detection runs on a small thumbnail and evaluates both the existing edge
/// detector and the contrast-region detector. The better card-like candidate
/// wins; unlike a fallback-only strategy, a weak edge candidate cannot prevent
/// a stronger contrast candidate from being considered.
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
            // A common false positive on textured backgrounds is a large edge
            // component whose rectangle has only a marginal ID-1 aspect match.
            // Prefer a strong contrast-region aspect match in that case.
            if edge.score.aspect_ratio < STRONG_ASPECT_SCORE
                && contrast.score.aspect_ratio >= STRONG_ASPECT_SCORE
            {
                return Some(contrast);
            }

            let edge_quality = candidate_quality(edge.score);
            let contrast_quality = candidate_quality(contrast.score);
            if contrast_quality > edge_quality {
                Some(contrast)
            } else {
                Some(edge)
            }
        }
    }
}

fn candidate_quality(score: CandidateScore) -> f32 {
    0.50 * score.aspect_ratio
        + 0.25 * score.rectangularity
        + 0.10 * score.area
        + 0.10 * score.alignment
        + 0.05 * score.edge_strength
}

/// Finds a card-like region whose luminance differs materially from the image
/// border. This detector is used only for Gallery initial-crop seeding.
pub fn detect_contrast_region(
    image: &DynamicImage,
    options: DetectionOptions,
) -> Option<DetectionResult> {
    let gray = image.to_luma8();
    let width = gray.width();
    let height = gray.height();
    if width < 16 || height < 16 {
        return None;
    }

    let (background_mean, background_std_dev) = border_statistics(&gray);
    let thresholds = [
        (background_std_dev * 1.10).max(MIN_CONTRAST),
        (background_std_dev * 0.80).max(MIN_CONTRAST * 0.75),
    ];

    thresholds
        .into_iter()
        .filter_map(|threshold| {
            let mask = gray
                .pixels()
                .map(|pixel| (pixel.0[0] as f32 - background_mean).abs() >= threshold)
                .collect::<Vec<_>>();
            let closed = dilate_mask(&mask, width, height, 1);

            connected_components(&closed, width, height)
                .into_iter()
                .filter_map(|component| candidate_from_component(&gray, &component, options))
                .max_by(|a, b| candidate_quality(a.score).total_cmp(&candidate_quality(b.score)))
        })
        .max_by(|a, b| candidate_quality(a.score).total_cmp(&candidate_quality(b.score)))
}

fn border_statistics(gray: &GrayImage) -> (f32, f32) {
    let width = gray.width();
    let height = gray.height();
    let band_x = (width / 24).max(1);
    let band_y = (height / 24).max(1);
    let mut sum = 0.0f64;
    let mut sum_sq = 0.0f64;
    let mut count = 0usize;

    for y in 0..height {
        for x in 0..width {
            if x < band_x || x >= width - band_x || y < band_y || y >= height - band_y {
                let value = gray.get_pixel(x, y).0[0] as f64;
                sum += value;
                sum_sq += value * value;
                count += 1;
            }
        }
    }

    if count == 0 {
        return (128.0, 0.0);
    }

    let mean = sum / count as f64;
    let variance = (sum_sq / count as f64 - mean * mean).max(0.0);
    (mean as f32, variance.sqrt() as f32)
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
    gray: &GrayImage,
    component: &[(u32, u32)],
    options: DetectionOptions,
) -> Option<DetectionResult> {
    let width = gray.width();
    let height = gray.height();
    let min_x = component.iter().map(|(x, _)| *x).min()?;
    let max_x = component.iter().map(|(x, _)| *x).max()?;
    let min_y = component.iter().map(|(_, y)| *y).min()?;
    let max_y = component.iter().map(|(_, y)| *y).max()?;

    if touches_border(min_x, min_y, max_x, max_y, width, height) {
        return None;
    }

    let box_width = (max_x - min_x + 1) as f32;
    let box_height = (max_y - min_y + 1) as f32;
    let image_area = width as f32 * height as f32;
    let area_ratio = box_width * box_height / image_area;
    if area_ratio < options.min_area_ratio.max(0.025) || area_ratio > MAX_AREA_RATIO {
        return None;
    }

    let actual_ratio = box_width / box_height;
    let aspect_score = options
        .expected_aspect_ratio
        .filter(|expected| expected.is_finite() && *expected > 0.0)
        .map(|expected| ratio_similarity(actual_ratio, expected))
        .unwrap_or(1.0);
    if aspect_score < 0.72 {
        return None;
    }

    let fill_ratio = (component.len() as f32 / (box_width * box_height)).clamp(0.0, 1.0);
    if fill_ratio < 0.34 {
        return None;
    }

    let (background_mean, _) = border_statistics(gray);
    let region_mean = component
        .iter()
        .map(|(x, y)| gray.get_pixel(*x, *y).0[0] as f32)
        .sum::<f32>()
        / component.len() as f32;
    let contrast_score = ((region_mean - background_mean).abs() / 80.0).clamp(0.0, 1.0);

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
                Point {
                    x: min_x as f32 / denom_x,
                    y: min_y as f32 / denom_y,
                },
                Point {
                    x: max_x as f32 / denom_x,
                    y: min_y as f32 / denom_y,
                },
                Point {
                    x: max_x as f32 / denom_x,
                    y: max_y as f32 / denom_y,
                },
                Point {
                    x: min_x as f32 / denom_x,
                    y: max_y as f32 / denom_y,
                },
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
    use image::{DynamicImage, GrayImage, Luma};

    use super::*;

    #[test]
    fn finds_bright_card_on_dark_background() {
        let mut image = GrayImage::from_pixel(320, 240, Luma([58]));
        for y in 100..170 {
            for x in 80..240 {
                image.put_pixel(x, y, Luma([190]));
            }
        }

        let result = detect_contrast_region(
            &DynamicImage::ImageLuma8(image),
            DetectionOptions {
                expected_aspect_ratio: Some(160.0 / 70.0),
                min_area_ratio: 0.03,
                ..DetectionOptions::default()
            },
        )
        .expect("bright card should be detected");

        assert!(result.score.aspect_ratio > 0.90);
        assert!(result.score.total > 0.60);
    }

    #[test]
    fn finds_dark_card_on_light_background() {
        let mut image = GrayImage::from_pixel(300, 220, Luma([220]));
        for y in 80..140 {
            for x in 75..225 {
                image.put_pixel(x, y, Luma([70]));
            }
        }

        let result = detect_contrast_region(
            &DynamicImage::ImageLuma8(image),
            DetectionOptions {
                expected_aspect_ratio: Some(150.0 / 60.0),
                min_area_ratio: 0.03,
                ..DetectionOptions::default()
            },
        );
        assert!(result.is_some());
    }

    #[test]
    fn hybrid_prefers_stronger_card_aspect_candidate() {
        let weak_edge = DetectionResult {
            quad: Quad {
                corners: [
                    Point { x: 0.1, y: 0.1 },
                    Point { x: 0.9, y: 0.1 },
                    Point { x: 0.9, y: 0.9 },
                    Point { x: 0.1, y: 0.9 },
                ],
            },
            score: CandidateScore {
                total: 0.72,
                area: 1.0,
                rectangularity: 0.90,
                aspect_ratio: 0.70,
                alignment: 1.0,
                edge_strength: 0.80,
            },
        };
        let strong_contrast = DetectionResult {
            quad: weak_edge.quad,
            score: CandidateScore {
                total: 0.75,
                area: 1.0,
                rectangularity: 0.80,
                aspect_ratio: 0.96,
                alignment: 0.85,
                edge_strength: 0.70,
            },
        };

        assert_eq!(
            choose_candidate(Some(weak_edge), Some(strong_contrast)),
            Some(strong_contrast)
        );
    }

    #[test]
    fn rejects_region_touching_image_border() {
        let mut image = GrayImage::from_pixel(240, 180, Luma([48]));
        for y in 80..140 {
            for x in 0..150 {
                image.put_pixel(x, y, Luma([190]));
            }
        }
        assert!(detect_contrast_region(
            &DynamicImage::ImageLuma8(image),
            DetectionOptions::default()
        )
        .is_none());
    }
}
