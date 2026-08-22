use std::io::Cursor;

use image::{
    codecs::jpeg::JpegEncoder, imageops::FilterType, DynamicImage, GenericImageView, ImageFormat,
};

use crate::model::{NormalizedRect, OutputFormat, ProcessorOptions};

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

    if options.grayscale {
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
    use image::{DynamicImage, GenericImageView, ImageBuffer, ImageFormat, Rgb};

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
