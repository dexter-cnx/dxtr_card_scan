use std::{ffi::CString, panic::AssertUnwindSafe, ptr};

use crate::{model::ProcessorOptions, processor::process_encoded};

const STATUS_OK: i32 = 0;
const STATUS_INVALID_ARGUMENT: i32 = 1;
const STATUS_PROCESSING_ERROR: i32 = 2;
const STATUS_PANIC: i32 = 3;

#[repr(C)]
pub struct CardScanResult {
    pub status: i32,
    pub data_ptr: *mut u8,
    pub data_len: usize,
    pub error_ptr: *mut std::ffi::c_char,
}

impl CardScanResult {
    fn success(data: Vec<u8>) -> *mut Self {
        let data = data.into_boxed_slice();
        let data_len = data.len();
        let data_ptr = Box::into_raw(data) as *mut u8;
        Box::into_raw(Box::new(Self {
            status: STATUS_OK,
            data_ptr,
            data_len,
            error_ptr: ptr::null_mut(),
        }))
    }

    fn error(status: i32, message: impl Into<String>) -> *mut Self {
        let message = message.into().replace('\0', " ");
        let error_ptr = CString::new(message)
            .expect("NUL bytes were removed")
            .into_raw();
        Box::into_raw(Box::new(Self {
            status,
            data_ptr: ptr::null_mut(),
            data_len: 0,
            error_ptr,
        }))
    }
}

#[no_mangle]
pub unsafe extern "C" fn card_scan_process(
    input_ptr: *const u8,
    input_len: usize,
    options_json_ptr: *const u8,
    options_json_len: usize,
) -> *mut CardScanResult {
    let execution = std::panic::catch_unwind(AssertUnwindSafe(|| {
        if input_ptr.is_null() || input_len == 0 {
            return CardScanResult::error(STATUS_INVALID_ARGUMENT, "input image is empty");
        }

        let input = unsafe { std::slice::from_raw_parts(input_ptr, input_len) };
        let options = if options_json_ptr.is_null() || options_json_len == 0 {
            ProcessorOptions::default()
        } else {
            let options_json =
                unsafe { std::slice::from_raw_parts(options_json_ptr, options_json_len) };
            match serde_json::from_slice::<ProcessorOptions>(options_json) {
                Ok(options) => options,
                Err(error) => {
                    return CardScanResult::error(
                        STATUS_INVALID_ARGUMENT,
                        format!("invalid options JSON: {error}"),
                    );
                }
            }
        };

        match process_encoded(input, options) {
            Ok(data) => CardScanResult::success(data),
            Err(error) => CardScanResult::error(STATUS_PROCESSING_ERROR, error),
        }
    }));

    execution.unwrap_or_else(|_| CardScanResult::error(STATUS_PANIC, "Rust processor panicked"))
}

#[no_mangle]
pub unsafe extern "C" fn card_scan_result_free(result_ptr: *mut CardScanResult) {
    if result_ptr.is_null() {
        return;
    }

    let result = unsafe { Box::from_raw(result_ptr) };
    if !result.data_ptr.is_null() && result.data_len > 0 {
        let slice = ptr::slice_from_raw_parts_mut(result.data_ptr, result.data_len);
        unsafe { drop(Box::from_raw(slice)) };
    }
    if !result.error_ptr.is_null() {
        unsafe { drop(CString::from_raw(result.error_ptr)) };
    }
}

#[cfg(test)]
mod tests {
    use std::ffi::CStr;

    use super::*;

    #[test]
    fn rejects_empty_input_without_panicking() {
        let result_ptr = unsafe { card_scan_process(ptr::null(), 0, ptr::null(), 0) };
        let result = unsafe { &*result_ptr };
        assert_eq!(result.status, STATUS_INVALID_ARGUMENT);
        assert!(!result.error_ptr.is_null());
        let message = unsafe { CStr::from_ptr(result.error_ptr) }.to_string_lossy();
        assert!(message.contains("empty"));
        unsafe { card_scan_result_free(result_ptr) };
    }
}
