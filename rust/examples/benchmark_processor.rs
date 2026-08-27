use std::env;
use std::io::Cursor;
use std::time::{Duration, Instant};

use dxtr_card_scan_processor::{analyze_quality, process_encoded, OutputFormat, ProcessorOptions};
use image::{DynamicImage, ImageFormat, Rgb, RgbImage};

fn main() {
    let iterations = parse_iterations();
    let input = synthetic_card_png(1600, 1000);
    let options = ProcessorOptions {
        auto_detect: true,
        warp_long_edge: Some(1600),
        enhance_for_ocr: true,
        grayscale: false,
        max_dimension: Some(2000),
        output_format: OutputFormat::Jpeg,
        jpeg_quality: 92,
        ..ProcessorOptions::default()
    };

    // Warm native/image-codec paths before measuring.
    let decoded = image::load_from_memory(&input).expect("synthetic PNG must decode");
    let _ = analyze_quality(&decoded);
    let _ = process_encoded(&input, &options).expect("processor warmup must succeed");

    let quality = measure(iterations, || {
        let image = image::load_from_memory(&input).expect("synthetic PNG must decode");
        let _ = analyze_quality(&image);
    });
    let process = measure(iterations, || {
        let _ = process_encoded(&input, &options).expect("processor benchmark must succeed");
    });

    println!("dxtr_card_scan processor benchmark");
    println!("input: 1600x1000 synthetic PNG ({} bytes)", input.len());
    println!("iterations: {iterations}");
    print_result("quality_decode_and_analysis", quality, iterations);
    print_result("detect_warp_and_ocr_process", process, iterations);
}

fn parse_iterations() -> u32 {
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        if arg == "--iterations" {
            return args
                .next()
                .expect("--iterations requires a value")
                .parse::<u32>()
                .expect("--iterations must be an integer")
                .max(1);
        }
    }
    20
}

fn measure(iterations: u32, mut operation: impl FnMut()) -> Duration {
    let start = Instant::now();
    for _ in 0..iterations {
        operation();
    }
    start.elapsed()
}

fn print_result(name: &str, elapsed: Duration, iterations: u32) {
    let total_ms = elapsed.as_secs_f64() * 1000.0;
    let mean_ms = total_ms / f64::from(iterations);
    println!("{name}: total={total_ms:.2}ms mean={mean_ms:.2}ms/op");
}

fn synthetic_card_png(width: u32, height: u32) -> Vec<u8> {
    let mut image = RgbImage::from_pixel(width, height, Rgb([35, 35, 35]));
    let margin_x = width / 8;
    let margin_y = height / 7;

    for y in margin_y..(height - margin_y) {
        for x in margin_x..(width - margin_x) {
            let stripe = ((x / 32) + (y / 24)) % 2;
            let base = if stripe == 0 { 225 } else { 238 };
            image.put_pixel(x, y, Rgb([base, base, base.saturating_sub(8)]));
        }
    }

    // Add dark horizontal details so edge/quality analysis has deterministic structure.
    for line in 0..6 {
        let top = margin_y + 90 + line * 75;
        for y in top..(top + 14).min(height - margin_y) {
            for x in (margin_x + 110)..(width - margin_x - 120) {
                image.put_pixel(x, y, Rgb([55, 60, 65]));
            }
        }
    }

    let mut cursor = Cursor::new(Vec::new());
    DynamicImage::ImageRgb8(image)
        .write_to(&mut cursor, ImageFormat::Png)
        .expect("synthetic image encoding must succeed");
    cursor.into_inner()
}
