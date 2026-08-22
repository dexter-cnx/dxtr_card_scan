mod ffi;
pub mod model;
pub mod processor;

pub use ffi::{card_scan_process, card_scan_result_free, CardScanResult};
pub use model::{NormalizedRect, OutputFormat, ProcessorOptions};
pub use processor::process_encoded;
