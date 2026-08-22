use std::io::Cursor;

use image::{
    codecs::jpeg::JpegEncoder, imageops::FilterType, DynamicImage, GenericImageView, GrayImage,
    ImageFormat,
};

use crate::{
    detection::{detect_card_quad, DetectionOptions},
    model::{NormalizedRect, OutputFormat, ProcessorOptions},
    warp::{warp_quad, WarpOptions},
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct PixelRect {
    left: u32,
    top: u32,
    right: u32,
    bottom: u32,
}

pub fn process_encoded(input: &[u8], options: ProcessorOptions) -> Result<Vec<u8>, String> {
    let options = options.validate()?;
    let mut image =
        image::load_from_memory(input).map_err(|error| format!("decode failed: {error}"))?;

    let raw_dimensions = image.dimensions();
    let crop = options
        .roi
        .map(|roi| quantize_normalized_roi(roi, raw_dimensions.0, raw_dimensions.1))
        .transpose()?;

    image = normalize_orientation(image, options.quarter_turns_clockwise);

    if let Some(raw_crop) = crop {
        let oriented_crop = rotate_pixel_rect(
            raw_crop,
            raw_dimensions.0,
            raw_dimensions.1,
            options.quarter_turns_clockwise,
        );
        image = crop_pixels(image, oriented_crop)?;
    }

    let perspective_quad = if options.auto_detect {
        Some(
            detect_card_quad(&image, DetectionOptions::default())
                .ok_or_else(|| "no card quadrilateral detected".to_owned())?
                .quad,
        )
    } else {
        options.perspective_quad
    };

    if let Some(quad) = perspective_quad {
        image = warp_quad(
            &image,
            quad,
            WarpOptions {
                output_long_edge: options.warp_long_edge,
            },
        )?;
    }

    if options.enhance_for_ocr {
        image = enhance_for_ocr(image);
    } else if options.grayscale {
        image = DynamicImage::ImageLuma8(image.to_luma8());
    }

    if let Some(max_dimension) = options.max_dimension {
        image = resize_to_max_dimension(image, max_dimension);
    }

    encode(image, options.output_format, options.jpeg_quality)
}

fn normalize_orientation(image: DynamicImage, quarter_turns_clockwise: u8) -> DynamicImage {
    match quarter_turns_clockwise % 4 {
        0 => image,
        1 => image.rotate90(),
        2 => image.rotate180(),
        3 => image.rotate270(),
        _ => unreachable!(),
    }
}

fn quantize_normalized_roi(
    roi: NormalizedRect,
    width: u32,
    height: u32,
) -> Result<PixelRect, String> {
    if width == 0 || height == 0 {
        return Err("decoded image has zero dimensions".to_owned());
    }

    let left = (roi.left * width as f32).floor() as u32;
    let top = (roi.top * height as f32).floor() as u32;
    let right = (roi.right * width as f32).ceil() as u32;
    let bottom = (roi.bottom * height as f32).ceil() as u32;

    let left = left.min(width - 1);
    let top = top.min(height - 1);
    let right = right.clamp(left + 1, width);
    let bottom = bottom.clamp(top + 1, height);

    Ok(PixelRect {
        left,
        top,
        right,
        bottom,
    })
}

fn rotate_pixel_rect(rect: PixelRect, width: u32, height: u32, quarter_turns: u8) -> PixelRect {
    match quarter_turns % 4 {
        0 => rect,
        1 => PixelRect {
            left: height - rect.bottom,
            top: rect.left,
            right: height - rect.top,
            bottom: rect.right,
        },
        2 => PixelRect {
            left: width - rect.right,
            top: height - rect.bottom,
            right: width - rect.left,
            bottom: height - rect.top,
        },
        3 => PixelRect {
            left: rect.top,
            top: width - rect.right,
            right: rect.bottom,
            bottom: width - rect.left,
        },
        _ => unreachable!(),
    }
}

fn crop_pixels(image: DynamicImage, rect: PixelRect) -> Result<DynamicImage, String> {
    let (width, height) = image.dimensions();
    if rect.left >= rect.right
        || rect.top >= rect.bottom
        || rect.right > width
        || rect.bottom > height
    {
        return Err("pixel crop is outside the oriented image".to_owned());
    }

    Ok(image.crop_imm(
        rect.left,
        rect.top,
        rect.right - rect.left,
        rect.bottom - rect.top,
    ))
}

fn enhance_for_ocr(image: DynamicImage) -> DynamicImage {
    let gray = image.to_luma8();
    let (low, high) = percentile_bounds(&gray, 0.02, 0.98);
    if high <= low {
        return DynamicImage::ImageLuma8(gray);
    }

    let scale = 255.0 / (high - low) as f32;
    let mut output = GrayImage::new(gray.width(), gray.height());
    for (x, y, pixel) in gray.enumerate_pixels() {
        let value = pixel.0[0];
        let stretched = if value <= low {
            0
        } else if value >= high {
            255
        } else {
            ((value - low) as f32 * scale).round().clamp(0.0, 255.0) as u8
        };
        output.put_pixel(x, y, image::Luma([stretched]));
    }
    DynamicImage::ImageLuma8(output)
}

fn percentile_bounds(image: &GrayImage, low_fraction: f64, high_fraction: f64) -> (u8, u8) {
    let mut histogram = [0u64; 256];
    for pixel in image.pixels() {
        histogram[pixel.0[0] as usize] += 1;
    }
    let total = image.width() as u64 * image.height() as u64;
    if total == 0 {
        return (0, 255);
    }

    let low_target = ((total as f64 * low_fraction).floor() as u64).clamp(1, total);
    let high_target = ((total as f64 * high_fraction).ceil() as u64).clamp(1, total);
    let mut cumulative = 0u64;
    let mut low = 0u8;
    let mut high = 255u8;
    for (value, count) in histogram.iter().copied().enumerate() {
        cumulative += count;
        if cumulative >= low_target {
            low = value as u8;
            break;
        }
    }

    cumulative = 0;
    for (value, count) in histogram.iter().copied().enumerate() {
        cumulative += count;
        if cumulative >= high_target {
            high = value as u8;
            break;
        }
    }
    (low, high)
}

fn resize_to_max_dimension(image: DynamicImage, max_dimension: u32) -> DynamicImage {
    let (width, height) = image.dimensions();
    let current_max = width.max(height);
    if current_max <= max_dimension {
        return image;
    }

    let scale = max_dimension as f64 / current_max as f64;
    let target_width = ((width as f64 * scale).round() as u32).max(1);
    let target_height = ((height as f64 * scale).round() as u32).max(1);
    image.resize_exact(target_width, target_height, FilterType::Lanczos3)
}

fn encode(image: DynamicImage, format: OutputFormat, jpeg_quality: u8) -> Result<Vec<u8>, String> {
    let mut output = Vec::new();
    match format {
        OutputFormat::Jpeg => {
            let mut encoder = JpegEncoder::new_with_quality(&mut output, jpeg_quality);
            encoder
                .encode_image(&image)
                .map_err(|error| format!("JPEG encode failed: {error}"))?;
        }
        OutputFormat::Png => {
            let mut cursor = Cursor::new(&mut output);
            image
                .write_to(&mut cursor, ImageFormat::Png)
                .map_err(|error| format!("PNG encode failed: {error}"))?;
        }
    }
    Ok(output)
}

#[cfg(test)]
mod tests {
    use image::{DynamicImage, GenericImageView, ImageBuffer, ImageFormat, Luma, Rgb};

    use crate::detection::{Point, Quad};

    use super::*;

    fn fixture(width: u32, height: u32) -> Vec<u8> {
        let image = ImageBuffer::from_fn(width, height, |x, y| {
            Rgb([(x % 255) as u8, (y % 255) as u8, ((x + y) % 255) as u8])
        });
        let mut bytes = Vec::new();
        DynamicImage::ImageRgb8(image)
            .write_to(&mut Cursor::new(&mut bytes), ImageFormat::Png)
            .unwrap();
        bytes
    }

    fn card_fixture(width: u32, height: u32) -> Vec<u8> {
        let mut image = ImageBuffer::from_pixel(width, height, Rgb([20, 20, 20]));
        for y in 20..height - 20 {
            for x in 15..width - 15 {
                image.put_pixel(x, y, Rgb([220, 220, 220]));
            }
        }
        let mut bytes = Vec::new();
        DynamicImage::ImageRgb8(image)
            .write_to(&mut Cursor::new(&mut bytes), ImageFormat::Png)
            .unwrap();
        bytes
    }

    fn decode(bytes: &[u8]) -> DynamicImage {
        image::load_from_memory(bytes).unwrap()
    }

    #[test]
    fn rotates_clockwise_and_swaps_dimensions() {
        let output = process_encoded(
            &fixture(80, 40),
            ProcessorOptions {
                quarter_turns_clockwise: 1,
                output_format: OutputFormat::Png,
                ..ProcessorOptions::default()
            },
        )
        .unwrap();

        assert_eq!(decode(&output).dimensions(), (40, 80));
    }

    #[test]
    fn maps_raw_roi_after_orientation_normalization() {
        let output = process_encoded(
            &fixture(100, 60),
            ProcessorOptions {
                quarter_turns_clockwise: 1,
                roi: Some(NormalizedRect {
                    left: 0.10,
                    top: 0.20,
                    right: 0.50,
                    bottom: 0.70,
                }),
                output_format: OutputFormat::Png,
                ..ProcessorOptions::default()
            },
        )
        .unwrap();

        assert_eq!(decode(&output).dimensions(), (30, 40));
    }

    #[test]
    fn preserves_pixel_aligned_roi_when_rotation_complements_recurring_fraction() {
        let output = process_encoded(
            &fixture(3, 3),
            ProcessorOptions {
                quarter_turns_clockwise: 1,
                roi: Some(NormalizedRect {
                    left: 1.0 / 3.0,
                    top: 0.0,
                    right: 1.0,
                    bottom: 1.0 / 3.0,
                }),
                output_format: OutputFormat::Png,
                ..ProcessorOptions::default()
            },
        )
        .unwrap();

        assert_eq!(decode(&output).dimensions(), (1, 2));
    }

    #[test]
    fn rotates_quantized_pixel_bounds_exactly() {
        let rect = PixelRect {
            left: 1,
            top: 0,
            right: 3,
            bottom: 1,
        };
        assert_eq!(
            rotate_pixel_rect(rect, 3, 3, 1),
            PixelRect {
                left: 2,
                top: 1,
                right: 3,
                bottom: 3,
            }
        );
    }

    #[test]
    fn manual_perspective_quad_warps_before_resize() {
        let output = process_encoded(
            &fixture(100, 80),
            ProcessorOptions {
                perspective_quad: Some(Quad {
                    corners: [
                        Point { x: 0.10, y: 0.20 },
                        Point { x: 0.90, y: 0.20 },
                        Point { x: 0.85, y: 0.80 },
                        Point { x: 0.15, y: 0.80 },
                    ],
                }),
                warp_long_edge: Some(60),
                output_format: OutputFormat::Png,
                ..ProcessorOptions::default()
            },
        )
        .unwrap();
        let image = decode(&output);
        assert_eq!(image.width(), 60);
        assert!(image.height() < image.width());
    }

    #[test]
    fn auto_detect_warps_card_fixture() {
        let output = process_encoded(
            &card_fixture(180, 120),
            ProcessorOptions {
                auto_detect: true,
                output_format: OutputFormat::Png,
                ..ProcessorOptions::default()
            },
        )
        .unwrap();
        let image = decode(&output);
        assert!(image.width() > image.height());
        assert!(image.width() < 180);
    }

    #[test]
    fn ocr_enhancement_stretches_grayscale_contrast() {
        let image = GrayImage::from_fn(100, 1, |x, _| Luma([100 + (x % 20) as u8]));
        let enhanced = enhance_for_ocr(DynamicImage::ImageLuma8(image)).to_luma8();
        let min = enhanced.pixels().map(|pixel| pixel.0[0]).min().unwrap();
        let max = enhanced.pixels().map(|pixel| pixel.0[0]).max().unwrap();
        assert_eq!(min, 0);
        assert_eq!(max, 255);
    }

    #[test]
    fn ocr_enhancement_keeps_uniform_single_pixel_unchanged() {
        let image = GrayImage::from_pixel(1, 1, Luma([100]));
        let enhanced = enhance_for_ocr(DynamicImage::ImageLuma8(image)).to_luma8();
        assert_eq!(enhanced.get_pixel(0, 0).0[0], 100);
    }

    #[test]
    fn resizes_without_upscaling() {
        let output = process_encoded(
            &fixture(120, 60),
            ProcessorOptions {
                max_dimension: Some(48),
                output_format: OutputFormat::Png,
                ..ProcessorOptions::default()
            },
        )
        .unwrap();
        assert_eq!(decode(&output).dimensions(), (48, 24));

        let unchanged = process_encoded(
            &fixture(30, 20),
            ProcessorOptions {
                max_dimension: Some(48),
                output_format: OutputFormat::Png,
                ..ProcessorOptions::default()
            },
        )
        .unwrap();
        assert_eq!(decode(&unchanged).dimensions(), (30, 20));
    }

    #[test]
    fn grayscale_output_is_luma() {
        let output = process_encoded(
            &fixture(20, 10),
            ProcessorOptions {
                grayscale: true,
                output_format: OutputFormat::Png,
                ..ProcessorOptions::default()
            },
        )
        .unwrap();

        assert!(matches!(decode(&output), DynamicImage::ImageLuma8(_)));
    }
}
