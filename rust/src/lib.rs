pub mod detection;
mod ffi;
pub mod model;
pub mod processor;
pub mod warp;

pub use detection::{
    detect_card_quad, CandidateScore, DetectionOptions, DetectionResult, Point, Quad,
};
pub use ffi::{card_scan_detect, card_scan_process, card_scan_result_free, CardScanResult};
pub use model::{NormalizedRect, OutputFormat, ProcessorOptions};
pub use processor::process_encoded;
pub use warp::{warp_quad, WarpOptions};
