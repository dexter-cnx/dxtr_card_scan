use std::collections::VecDeque;

use image::{DynamicImage, GrayImage};

use crate::detection::{
    detect_card_quad, CandidateScore, DetectionOptions, DetectionResult, Point, Quad,
};

const MIN_CONTRAST: f32 = 24.0;
const MIN_COMPONENT_PIXELS: usize = 48;
const MAX_AREA_RATIO: f32 = 0.75;
const BORDER_MARGIN_RATIO: f32 = 0.01;

/// Runs the existing edge detector first and falls back to a contrast-region
/// detector only when the edge detector cannot produce a candidate.
pub fn detect_card_quad_with_contrast_fallback(
    image: &DynamicImage,
    options: DetectionOptions,
) -> Option<DetectionResult> {
    detect_card_quad(image, options).or_else(|| detect_contrast_region(image, options))
}

/// Finds a card-like region whose luminance differs materially from the image
/// border. This is intended as a conservative fallback for Gallery initial
/// crop seeding, not as a replacement for the edge detector.
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
    let threshold = (background_std_dev * 1.35).max(MIN_CONTRAST);

    let mask = gray
        .pixels()
        .map(|pixel| (pixel.0[0] as f32 - background_mean).abs() >= threshold)
        .collect::<Vec<_>>();
    let closed = dilate_mask(&mask, width, height, 2);

    connected_components(&closed, width, height)
        .into_iter()
        .filter_map(|component| candidate_from_component(&gray, &component, options))
        .max_by(|a, b| a.score.total.total_cmp(&b.score.total))
}

fn border_statistics(gray: &GrayImage) -> (f32, f32) {
    let width = gray.width();
    let height = gray.height();
    let band_x = (width / 20).max(1);
    let band_y = (height / 20).max(1);
    let mut values = Vec::new();

    for y in 0..height {
        for x in 0..width {
            if x < band_x || x >= width - band_x || y < band_y || y >= height - band_y {
                values.push(gray.get_pixel(x, y).0[0] as f32);
            }
        }
    }

    if values.is_empty() {
        return (128.0, 0.0);
    }

    let mean = values.iter().sum::<f32>() / values.len() as f32;
    let variance = values
        .iter()
        .map(|value| {
            let delta = *value - mean;
            delta * delta
        })
        .sum::<f32>()
        / values.len() as f32;
    (mean, variance.sqrt())
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
    if area_ratio < options.min_area_ratio.max(0.035) || area_ratio > MAX_AREA_RATIO {
        return None;
    }

    let actual_ratio = box_width / box_height;
    let aspect_score = options
        .expected_aspect_ratio
        .filter(|expected| expected.is_finite() && *expected > 0.0)
        .map(|expected| ratio_similarity(actual_ratio, expected))
        .unwrap_or(1.0);
    if aspect_score < 0.68 {
        return None;
    }

    let fill_ratio = (component.len() as f32 / (box_width * box_height)).clamp(0.0, 1.0);
    if fill_ratio < 0.42 {
        return None;
    }

    let (background_mean, _) = border_statistics(gray);
    let region_mean = component
        .iter()
        .map(|(x, y)| gray.get_pixel(*x, *y).0[0] as f32)
        .sum::<f32>()
        / component.len() as f32;
    let contrast_score = ((region_mean - background_mean).abs() / 96.0).clamp(0.0, 1.0);

    let center_x = (min_x + max_x) as f32 * 0.5;
    let center_y = (min_y + max_y) as f32 * 0.5;
    let dx = (center_x - width as f32 * 0.5).abs() / (width as f32 * 0.5);
    let dy = (center_y - height as f32 * 0.5).abs() / (height as f32 * 0.5);
    let alignment = (1.0 - (dx * dx + dy * dy).sqrt() / 2.0f32.sqrt()).clamp(0.0, 1.0);
    let area_score = area_plausibility(area_ratio);
    let total = 0.15 * area_score
        + 0.25 * fill_ratio
        + 0.40 * aspect_score
        + 0.10 * alignment
        + 0.10 * contrast_score;

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
    if area_ratio <= 0.08 {
        (area_ratio / 0.08).clamp(0.0, 1.0)
    } else if area_ratio <= 0.45 {
        1.0
    } else {
        ((0.75 - area_ratio) / 0.30).clamp(0.0, 1.0)
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
    fn rejects_region_touching_image_border() {
        let mut image = GrayImage::from_pixel(240, 180, Luma([48]));
        for y in 80..140 {
            for x in 0..150 {
                image.put_pixel(x, y, Luma([190]));
            }
        }
        assert!(detect_contrast_region(&DynamicImage::ImageLuma8(image), DetectionOptions::default()).is_none());
    }
}
