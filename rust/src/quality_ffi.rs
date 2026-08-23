use std::{ffi::CString, panic::AssertUnwindSafe, ptr};

use crate::{ffi::CardScanResult, quality::analyze_quality};

const STATUS_OK: i32 = 0;
const STATUS_INVALID_ARGUMENT: i32 = 1;
const STATUS_PROCESSING_ERROR: i32 = 2;
const STATUS_PANIC: i32 = 3;

fn success(data: Vec<u8>) -> *mut CardScanResult {
    let data = data.into_boxed_slice();
    let data_len = data.len();
    let data_ptr = Box::into_raw(data) as *mut u8;
    Box::into_raw(Box::new(CardScanResult {
        status: STATUS_OK,
        data_ptr,
        data_len,
        error_ptr: ptr::null_mut(),
    }))
}

fn error(status: i32, message: impl Into<String>) -> *mut CardScanResult {
    let message = message.into().replace('\0', " ");
    let error_ptr = CString::new(message)
        .expect("NUL bytes were removed")
        .into_raw();
    Box::into_raw(Box::new(CardScanResult {
        status,
        data_ptr: ptr::null_mut(),
        data_len: 0,
        error_ptr,
    }))
}

/// Analyzes capture quality and returns JSON measurement metadata.
///
/// # Safety
///
/// `input_ptr` must point to at least `input_len` readable bytes for the duration of this call.
/// The returned pointer, when non-null, is owned by Rust and must be released exactly once with
/// `card_scan_result_free`.
#[no_mangle]
pub unsafe extern "C" fn card_scan_analyze_quality(
    input_ptr: *const u8,
    input_len: usize,
) -> *mut CardScanResult {
    let execution = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if input_ptr.is_null() || input_len == 0 {
            return error(STATUS_INVALID_ARGUMENT, "input image is empty");
        }

        let input = unsafe { std::slice::from_raw_parts(input_ptr, input_len) };
        let image = match image::load_from_memory(input) {
            Ok(image) => image,
            Err(decode_error) => {
                return error(
                    STATUS_PROCESSING_ERROR,
                    format!("unable to decode image: {decode_error}"),
                );
            }
        };

        match serde_json::to_vec(&analyze_quality(&image)) {
            Ok(data) => success(data),
            Err(encode_error) => error(
                STATUS_PROCESSING_ERROR,
                format!("unable to encode quality analysis: {encode_error}"),
            ),
        }
    }));

    execution.unwrap_or_else(|_| error(STATUS_PANIC, "Rust quality analyzer panicked"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_input_without_panicking() {
        let result_ptr = unsafe { card_scan_analyze_quality(ptr::null(), 0) };
        let result = unsafe { &*result_ptr };
        assert_eq!(result.status, STATUS_INVALID_ARGUMENT);
        assert!(!result.error_ptr.is_null());
        unsafe { crate::ffi::card_scan_result_free(result_ptr) };
    }
}