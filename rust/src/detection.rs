use std::collections::VecDeque;

use image::{DynamicImage, GrayImage};

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Point {
    pub x: f32,
    pub y: f32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Quad {
    /// Clockwise corners starting at top-left, normalized to [0, 1].
    pub corners: [Point; 4],
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CandidateScore {
    pub total: f32,
    pub area: f32,
    pub rectangularity: f32,
    pub aspect_ratio: f32,
    pub alignment: f32,
    pub edge_strength: f32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DetectionResult {
    pub quad: Quad,
    pub score: CandidateScore,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DetectionOptions {
    /// Expected width / height ratio, for example 85.60 / 53.98 for ID-1.
    pub expected_aspect_ratio: Option<f32>,
    /// Reject candidates smaller than this fraction of the image area.
    pub min_area_ratio: f32,
    /// Gradient threshold = mean + `edge_sigma` * standard deviation.
    pub edge_sigma: f32,
}

impl Default for DetectionOptions {
    fn default() -> Self {
        Self {
            expected_aspect_ratio: Some(85.60 / 53.98),
            min_area_ratio: 0.08,
            edge_sigma: 0.65,
        }
    }
}

pub fn detect_card_quad(
    image: &DynamicImage,
    options: DetectionOptions,
) -> Option<DetectionResult> {
    let gray = image.to_luma8();
    if gray.width() < 8 || gray.height() < 8 {
        return None;
    }

    let blurred = box_blur_3x3(&gray);
    let (gradient, threshold) = sobel_gradient(&blurred, options.edge_sigma);
    let edges = gradient
        .iter()
        .map(|value| *value >= threshold)
        .collect::<Vec<_>>();

    connected_edge_components(&edges, gray.width(), gray.height())
        .into_iter()
        .filter_map(|component| {
            candidate_from_component(
                &component,
                &gradient,
                gray.width(),
                gray.height(),
                options,
            )
        })
        .max_by(|a, b| a.score.total.total_cmp(&b.score.total))
}

fn box_blur_3x3(input: &GrayImage) -> GrayImage {
    let (width, height) = input.dimensions();
    let mut output = GrayImage::new(width, height);
    for y in 0..height {
        for x in 0..width {
            let mut sum = 0u32;
            let mut count = 0u32;
            for dy in -1i32..=1 {
                for dx in -1i32..=1 {
                    let nx = x as i32 + dx;
                    let ny = y as i32 + dy;
                    if nx >= 0 && ny >= 0 && nx < width as i32 && ny < height as i32 {
                        sum += input.get_pixel(nx as u32, ny as u32).0[0] as u32;
                        count += 1;
                    }
                }
            }
            output.put_pixel(x, y, image::Luma([(sum / count) as u8]));
        }
    }
    output
}

fn sobel_gradient(input: &GrayImage, sigma: f32) -> (Vec<f32>, f32) {
    let (width, height) = input.dimensions();
    let mut gradient = vec![0.0; (width * height) as usize];
    let mut sum = 0.0f64;
    let mut sum_sq = 0.0f64;
    let mut count = 0usize;

    for y in 1..height - 1 {
        for x in 1..width - 1 {
            let sample = |dx: i32, dy: i32| -> f32 {
                input
                    .get_pixel((x as i32 + dx) as u32, (y as i32 + dy) as u32)
                    .0[0] as f32
            };
            let gx = -sample(-1, -1) + sample(1, -1) - 2.0 * sample(-1, 0)
                + 2.0 * sample(1, 0)
                - sample(-1, 1)
                + sample(1, 1);
            let gy = -sample(-1, -1) - 2.0 * sample(0, -1) - sample(1, -1)
                + sample(-1, 1)
                + 2.0 * sample(0, 1)
                + sample(1, 1);
            let magnitude = (gx * gx + gy * gy).sqrt();
            gradient[(y * width + x) as usize] = magnitude;
            sum += magnitude as f64;
            sum_sq += (magnitude * magnitude) as f64;
            count += 1;
        }
    }

    if count == 0 {
        return (gradient, f32::INFINITY);
    }
    let mean = (sum / count as f64) as f32;
    let variance = ((sum_sq / count as f64) - (mean as f64 * mean as f64)).max(0.0);
    let std_dev = variance.sqrt() as f32;
    (gradient, mean + sigma.max(0.0) * std_dev)
}

fn connected_edge_components(edges: &[bool], width: u32, height: u32) -> Vec<Vec<(u32, u32)>> {
    let mut visited = vec![false; edges.len()];
    let mut components = Vec::new();

    for y in 0..height {
        for x in 0..width {
            let index = (y * width + x) as usize;
            if !edges[index] || visited[index] {
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
                        if edges[nindex] && !visited[nindex] {
                            visited[nindex] = true;
                            queue.push_back((nx as u32, ny as u32));
                        }
                    }
                }
            }
            if component.len() >= 12 {
                components.push(component);
            }
        }
    }
    components
}

fn candidate_from_component(
    component: &[(u32, u32)],
    gradient: &[f32],
    width: u32,
    height: u32,
    options: DetectionOptions,
) -> Option<DetectionResult> {
    let points = component
        .iter()
        .map(|&(x, y)| IPoint {
            x: x as i32,
            y: y as i32,
        })
        .collect::<Vec<_>>();
    let hull = convex_hull(points);
    if hull.len() < 4 {
        return None;
    }
    let corners = extreme_quad(&hull)?;

    let image_area = width as f32 * height as f32;
    let polygon_area = polygon_area_i(&corners);
    let area_ratio = polygon_area / image_area;
    if area_ratio < options.min_area_ratio.clamp(0.0, 1.0) {
        return None;
    }

    let top = distance(corners[0], corners[1]);
    let right = distance(corners[1], corners[2]);
    let bottom = distance(corners[2], corners[3]);
    let left = distance(corners[3], corners[0]);
    let card_width = (top + bottom) * 0.5;
    let card_height = (left + right) * 0.5;
    if card_width < 2.0 || card_height < 2.0 {
        return None;
    }

    let min_x = corners.iter().map(|point| point.x).min()? as f32;
    let max_x = corners.iter().map(|point| point.x).max()? as f32;
    let min_y = corners.iter().map(|point| point.y).min()? as f32;
    let max_y = corners.iter().map(|point| point.y).max()? as f32;
    let bbox_area = ((max_x - min_x).max(1.0)) * ((max_y - min_y).max(1.0));
    let rectangularity = (polygon_area / bbox_area).clamp(0.0, 1.0);

    let detected_ratio = card_width / card_height;
    let aspect_score = options
        .expected_aspect_ratio
        .filter(|expected| expected.is_finite() && *expected > 0.0)
        .map(|expected| ratio_similarity(detected_ratio, expected))
        .unwrap_or(1.0);

    let center_x = corners.iter().map(|point| point.x as f32).sum::<f32>() / 4.0;
    let center_y = corners.iter().map(|point| point.y as f32).sum::<f32>() / 4.0;
    let dx = (center_x - width as f32 * 0.5).abs() / (width as f32 * 0.5);
    let dy = (center_y - height as f32 * 0.5).abs() / (height as f32 * 0.5);
    let alignment = (1.0 - (dx * dx + dy * dy).sqrt() / 2.0f32.sqrt()).clamp(0.0, 1.0);

    let max_gradient = gradient.iter().copied().fold(0.0f32, f32::max).max(1.0);
    let edge_strength = (component
        .iter()
        .map(|&(x, y)| gradient[(y * width + x) as usize])
        .sum::<f32>()
        / component.len() as f32
        / max_gradient)
        .clamp(0.0, 1.0);

    let area_score = (area_ratio / 0.65).clamp(0.0, 1.0);
    let total = 0.30 * area_score
        + 0.20 * rectangularity
        + 0.25 * aspect_score
        + 0.10 * alignment
        + 0.15 * edge_strength;

    Some(DetectionResult {
        quad: Quad {
            corners: corners.map(|point| Point {
                x: point.x as f32 / width.saturating_sub(1).max(1) as f32,
                y: point.y as f32 / height.saturating_sub(1).max(1) as f32,
            }),
        },
        score: CandidateScore {
            total,
            area: area_score,
            rectangularity,
            aspect_ratio: aspect_score,
            alignment,
            edge_strength,
        },
    })
}

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
struct IPoint {
    x: i32,
    y: i32,
}

fn convex_hull(mut points: Vec<IPoint>) -> Vec<IPoint> {
    points.sort_unstable();
    points.dedup();
    if points.len() <= 2 {
        return points;
    }

    let mut lower = Vec::new();
    for point in points.iter().copied() {
        while lower.len() >= 2
            && cross(lower[lower.len() - 2], lower[lower.len() - 1], point) <= 0
        {
            lower.pop();
        }
        lower.push(point);
    }

    let mut upper = Vec::new();
    for point in points.iter().rev().copied() {
        while upper.len() >= 2
            && cross(upper[upper.len() - 2], upper[upper.len() - 1], point) <= 0
        {
            upper.pop();
        }
        upper.push(point);
    }
    lower.pop();
    upper.pop();
    lower.extend(upper);
    lower
}

fn cross(origin: IPoint, a: IPoint, b: IPoint) -> i64 {
    (a.x - origin.x) as i64 * (b.y - origin.y) as i64
        - (a.y - origin.y) as i64 * (b.x - origin.x) as i64
}

fn extreme_quad(hull: &[IPoint]) -> Option<[IPoint; 4]> {
    let top_left = *hull.iter().min_by_key(|point| point.x + point.y)?;
    let bottom_right = *hull.iter().max_by_key(|point| point.x + point.y)?;
    let top_right = *hull.iter().max_by_key(|point| point.x - point.y)?;
    let bottom_left = *hull.iter().min_by_key(|point| point.x - point.y)?;
    let corners = [top_left, top_right, bottom_right, bottom_left];
    if corners.iter().enumerate().any(|(index, point)| {
        corners
            .iter()
            .skip(index + 1)
            .any(|other| point == other)
    }) {
        return None;
    }
    Some(corners)
}

fn polygon_area_i(corners: &[IPoint; 4]) -> f32 {
    let mut sum = 0i64;
    for index in 0..4 {
        let a = corners[index];
        let b = corners[(index + 1) % 4];
        sum += a.x as i64 * b.y as i64 - b.x as i64 * a.y as i64;
    }
    sum.unsigned_abs() as f32 * 0.5
}

fn distance(a: IPoint, b: IPoint) -> f32 {
    let dx = (a.x - b.x) as f32;
    let dy = (a.y - b.y) as f32;
    (dx * dx + dy * dy).sqrt()
}

fn ratio_similarity(actual: f32, expected: f32) -> f32 {
    if !actual.is_finite() || actual <= 0.0 {
        return 0.0;
    }
    let direct = (actual / expected).ln().abs();
    let rotated = (actual * expected).ln().abs();
    (-direct.min(rotated)).exp().clamp(0.0, 1.0)
}

#[cfg(test)]
mod tests {
    use image::{DynamicImage, GrayImage, Luma};

    use super::*;

    fn rectangle_fixture(width: u32, height: u32, inset_x: u32, inset_y: u32) -> DynamicImage {
        let mut image = GrayImage::from_pixel(width, height, Luma([24]));
        let right = width - inset_x - 1;
        let bottom = height - inset_y - 1;
        for y in inset_y..=bottom {
            for x in inset_x..=right {
                image.put_pixel(x, y, Luma([220]));
            }
        }
        DynamicImage::ImageLuma8(image)
    }

    #[test]
    fn detects_centered_card_rectangle() {
        let image = rectangle_fixture(180, 120, 20, 20);
        let result = detect_card_quad(
            &image,
            DetectionOptions {
                expected_aspect_ratio: Some(140.0 / 80.0),
                ..DetectionOptions::default()
            },
        )
        .expect("rectangle should be detected");

        assert!(result.score.total > 0.60, "score={:?}", result.score);
        assert!(result.score.rectangularity > 0.90);
        assert!(result.score.aspect_ratio > 0.85);
        let [tl, tr, br, bl] = result.quad.corners;
        assert!(tl.x < tr.x && tl.y < bl.y);
        assert!(br.x > bl.x && br.y > tr.y);
    }

    #[test]
    fn rejects_tiny_component_by_area() {
        let image = rectangle_fixture(180, 120, 80, 50);
        let result = detect_card_quad(
            &image,
            DetectionOptions {
                min_area_ratio: 0.20,
                ..DetectionOptions::default()
            },
        );
        assert!(result.is_none());
    }

    #[test]
    fn aspect_score_accepts_portrait_rotation() {
        let expected = 85.60 / 53.98;
        assert!(ratio_similarity(expected, expected) > 0.99);
        assert!(ratio_similarity(1.0 / expected, expected) > 0.99);
    }

    #[test]
    fn convex_hull_removes_interior_points() {
        let hull = convex_hull(vec![
            IPoint { x: 0, y: 0 },
            IPoint { x: 10, y: 0 },
            IPoint { x: 10, y: 10 },
            IPoint { x: 0, y: 10 },
            IPoint { x: 5, y: 5 },
        ]);
        assert_eq!(hull.len(), 4);
    }
}
