use image::{DynamicImage, GenericImageView, Rgba, RgbaImage};

use crate::{
    detection::{Point, Quad},
    model::MAX_WARP_LONG_EDGE,
};

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct WarpOptions {
    /// Optional output long-edge size. When omitted, source edge lengths are preserved.
    pub output_long_edge: Option<u32>,
}

pub fn warp_quad(
    image: &DynamicImage,
    quad: Quad,
    options: WarpOptions,
) -> Result<DynamicImage, String> {
    let (source_width, source_height) = image.dimensions();
    if source_width < 2 || source_height < 2 {
        return Err("source image is too small for perspective warp".to_owned());
    }

    let mut corners = quad
        .corners
        .map(|point| normalized_to_pixel(point, source_width, source_height));
    validate_corners(&corners, source_width, source_height)?;
    corners = orient_long_edge_first(corners);

    let top = distance(corners[0], corners[1]);
    let bottom = distance(corners[3], corners[2]);
    let left = distance(corners[0], corners[3]);
    let right = distance(corners[1], corners[2]);
    let natural_width = ((top + bottom) * 0.5).round().max(1.0) as u32;
    let natural_height = ((left + right) * 0.5).round().max(1.0) as u32;
    if natural_width < 2 || natural_height < 2 {
        return Err("quadrilateral is too small for perspective warp".to_owned());
    }

    let (output_width, output_height) =
        output_dimensions(natural_width, natural_height, options.output_long_edge)?;
    let transform = ProjectiveMap::from_unit_square(corners)?;
    let source = image.to_rgba8();
    let mut output = RgbaImage::new(output_width, output_height);

    for y in 0..output_height {
        let v = if output_height == 1 {
            0.0
        } else {
            y as f64 / (output_height - 1) as f64
        };
        for x in 0..output_width {
            let u = if output_width == 1 {
                0.0
            } else {
                x as f64 / (output_width - 1) as f64
            };
            let (source_x, source_y) = transform.map(u, v)?;
            output.put_pixel(x, y, bilinear_sample(&source, source_x, source_y));
        }
    }

    Ok(DynamicImage::ImageRgba8(output))
}

fn normalized_to_pixel(point: Point, width: u32, height: u32) -> PixelPoint {
    PixelPoint {
        x: point.x as f64 * width.saturating_sub(1) as f64,
        y: point.y as f64 * height.saturating_sub(1) as f64,
    }
}

fn validate_corners(corners: &[PixelPoint; 4], width: u32, height: u32) -> Result<(), String> {
    let max_x = width.saturating_sub(1) as f64;
    let max_y = height.saturating_sub(1) as f64;
    for point in corners {
        if !point.x.is_finite() || !point.y.is_finite() {
            return Err("quadrilateral coordinates must be finite".to_owned());
        }
        if point.x < 0.0 || point.y < 0.0 || point.x > max_x || point.y > max_y {
            return Err("quadrilateral must stay inside the source image".to_owned());
        }
    }
    let area = polygon_area(corners).abs();
    if area < 1.0 {
        return Err("quadrilateral area is too small".to_owned());
    }
    Ok(())
}

fn orient_long_edge_first(mut corners: [PixelPoint; 4]) -> [PixelPoint; 4] {
    let pair_a = (distance(corners[0], corners[1]) + distance(corners[2], corners[3])) * 0.5;
    let pair_b = (distance(corners[1], corners[2]) + distance(corners[3], corners[0])) * 0.5;
    if pair_b > pair_a {
        corners.rotate_left(1);
    }

    // The long-edge pair can still be 180 degrees ambiguous: a cyclic quad
    // may begin on the bottom edge even though its winding is otherwise
    // correct. Keep the source image's upper long edge mapped to the output
    // top so rectification never turns an upright card upside down merely
    // because the detector chose a different cyclic start index.
    let first_edge_mid_y = (corners[0].y + corners[1].y) * 0.5;
    let opposite_edge_mid_y = (corners[2].y + corners[3].y) * 0.5;
    if opposite_edge_mid_y < first_edge_mid_y {
        corners.rotate_left(2);
    }

    corners
}

fn output_dimensions(
    width: u32,
    height: u32,
    long_edge: Option<u32>,
) -> Result<(u32, u32), String> {
    let Some(long_edge) = long_edge else {
        return Ok((width, height));
    };
    if !(2..=MAX_WARP_LONG_EDGE).contains(&long_edge) {
        return Err(format!(
            "output_long_edge must be in 2..={MAX_WARP_LONG_EDGE}"
        ));
    }
    let current_long = width.max(height) as f64;
    let scale = long_edge as f64 / current_long;
    Ok((
        ((width as f64 * scale).round() as u32).max(2),
        ((height as f64 * scale).round() as u32).max(2),
    ))
}

#[derive(Clone, Copy, Debug)]
struct PixelPoint {
    x: f64,
    y: f64,
}

fn distance(a: PixelPoint, b: PixelPoint) -> f64 {
    let dx = a.x - b.x;
    let dy = a.y - b.y;
    (dx * dx + dy * dy).sqrt()
}

fn polygon_area(corners: &[PixelPoint; 4]) -> f64 {
    let mut sum = 0.0;
    for index in 0..4 {
        let a = corners[index];
        let b = corners[(index + 1) % 4];
        sum += a.x * b.y - b.x * a.y;
    }
    sum * 0.5
}

#[derive(Clone, Copy, Debug)]
struct ProjectiveMap {
    a: f64,
    b: f64,
    c: f64,
    d: f64,
    e: f64,
    f: f64,
    g: f64,
    h: f64,
}

impl ProjectiveMap {
    fn from_unit_square(corners: [PixelPoint; 4]) -> Result<Self, String> {
        let [p0, p1, p2, p3] = corners;
        let dx1 = p1.x - p2.x;
        let dx2 = p3.x - p2.x;
        let dx3 = p0.x - p1.x + p2.x - p3.x;
        let dy1 = p1.y - p2.y;
        let dy2 = p3.y - p2.y;
        let dy3 = p0.y - p1.y + p2.y - p3.y;

        let (g, h) = if dx3.abs() < 1e-9 && dy3.abs() < 1e-9 {
            (0.0, 0.0)
        } else {
            let denominator = dx1 * dy2 - dx2 * dy1;
            if denominator.abs() < 1e-12 {
                return Err("quadrilateral produces a singular perspective transform".to_owned());
            }
            (
                (dx3 * dy2 - dx2 * dy3) / denominator,
                (dx1 * dy3 - dx3 * dy1) / denominator,
            )
        };

        Ok(Self {
            a: p1.x - p0.x + g * p1.x,
            b: p3.x - p0.x + h * p3.x,
            c: p0.x,
            d: p1.y - p0.y + g * p1.y,
            e: p3.y - p0.y + h * p3.y,
            f: p0.y,
            g,
            h,
        })
    }

    fn map(self, u: f64, v: f64) -> Result<(f64, f64), String> {
        let denominator = self.g * u + self.h * v + 1.0;
        if denominator.abs() < 1e-12 {
            return Err("perspective transform reached a singular sample".to_owned());
        }
        Ok((
            (self.a * u + self.b * v + self.c) / denominator,
            (self.d * u + self.e * v + self.f) / denominator,
        ))
    }
}

fn bilinear_sample(image: &RgbaImage, x: f64, y: f64) -> Rgba<u8> {
    let max_x = image.width().saturating_sub(1) as f64;
    let max_y = image.height().saturating_sub(1) as f64;
    let x = x.clamp(0.0, max_x);
    let y = y.clamp(0.0, max_y);
    let x0 = x.floor() as u32;
    let y0 = y.floor() as u32;
    let x1 = (x0 + 1).min(image.width() - 1);
    let y1 = (y0 + 1).min(image.height() - 1);
    let tx = x - x0 as f64;
    let ty = y - y0 as f64;
    let p00 = image.get_pixel(x0, y0).0;
    let p10 = image.get_pixel(x1, y0).0;
    let p01 = image.get_pixel(x0, y1).0;
    let p11 = image.get_pixel(x1, y1).0;
    let mut channels = [0u8; 4];
    for channel in 0..4 {
        let top = p00[channel] as f64 * (1.0 - tx) + p10[channel] as f64 * tx;
        let bottom = p01[channel] as f64 * (1.0 - tx) + p11[channel] as f64 * tx;
        channels[channel] = (top * (1.0 - ty) + bottom * ty).round().clamp(0.0, 255.0) as u8;
    }
    Rgba(channels)
}

#[cfg(test)]
mod tests {
    use image::{DynamicImage, GenericImageView, Rgba, RgbaImage};

    use super::*;

    fn fixture() -> DynamicImage {
        let image = RgbaImage::from_fn(100, 80, |x, y| Rgba([x as u8, y as u8, 50, 255]));
        DynamicImage::ImageRgba8(image)
    }

    #[test]
    fn axis_aligned_quad_preserves_expected_dimensions() {
        let result = warp_quad(
            &fixture(),
            Quad {
                corners: [
                    Point { x: 0.10, y: 0.25 },
                    Point { x: 0.90, y: 0.25 },
                    Point { x: 0.90, y: 0.75 },
                    Point { x: 0.10, y: 0.75 },
                ],
            },
            WarpOptions::default(),
        )
        .unwrap();
        let (width, height) = result.dimensions();
        assert!(width > height);
        assert!((width as i32 - 79).abs() <= 1);
        assert!((height as i32 - 40).abs() <= 1);
    }

    #[test]
    fn cyclic_start_on_bottom_edge_does_not_flip_output_upside_down() {
        let result = warp_quad(
            &fixture(),
            Quad {
                corners: [
                    Point { x: 0.90, y: 0.75 },
                    Point { x: 0.10, y: 0.75 },
                    Point { x: 0.10, y: 0.25 },
                    Point { x: 0.90, y: 0.25 },
                ],
            },
            WarpOptions::default(),
        )
        .unwrap()
        .to_rgba8();

        let top_left = result.get_pixel(0, 0).0;
        let bottom_left = result.get_pixel(0, result.height() - 1).0;
        assert!(top_left[1] < bottom_left[1]);
        assert!(top_left[0] < result.get_pixel(result.width() - 1, 0).0[0]);
    }

    #[test]
    fn portrait_order_is_rotated_to_landscape_long_edge() {
        let result = warp_quad(
            &fixture(),
            Quad {
                corners: [
                    Point { x: 0.35, y: 0.05 },
                    Point { x: 0.70, y: 0.50 },
                    Point { x: 0.35, y: 0.95 },
                    Point { x: 0.00, y: 0.50 },
                ],
            },
            WarpOptions::default(),
        )
        .unwrap();
        let (width, height) = result.dimensions();
        assert!(width >= height);
    }

    #[test]
    fn output_long_edge_scales_without_changing_aspect() {
        let result = warp_quad(
            &fixture(),
            Quad {
                corners: [
                    Point { x: 0.10, y: 0.20 },
                    Point { x: 0.90, y: 0.20 },
                    Point { x: 0.90, y: 0.70 },
                    Point { x: 0.10, y: 0.70 },
                ],
            },
            WarpOptions {
                output_long_edge: Some(200),
            },
        )
        .unwrap();
        assert_eq!(result.width(), 200);
        assert!(result.height() > 90 && result.height() < 110);
    }

    #[test]
    fn rejects_oversized_output_long_edge() {
        let error = output_dimensions(100, 60, Some(MAX_WARP_LONG_EDGE + 1)).unwrap_err();
        assert!(error.contains("output_long_edge"));
    }

    #[test]
    fn rejects_degenerate_quad() {
        let error = warp_quad(
            &fixture(),
            Quad {
                corners: [Point { x: 0.5, y: 0.5 }; 4],
            },
            WarpOptions::default(),
        )
        .unwrap_err();
        assert!(error.contains("area"));
    }
}
