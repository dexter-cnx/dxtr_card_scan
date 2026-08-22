# Rust processor

This crate is the deterministic native preprocessing core for `dxtr_card_scan`.

Current v0.2 foundation supports:
- encoded JPEG/PNG input;
- explicit clockwise quarter-turn orientation normalization;
- normalized raw-image ROI crop, transformed consistently after orientation normalization;
- optional grayscale conversion;
- optional max-dimension resize without upscaling;
- JPEG or PNG output encoding;
- a stable C ABI using UTF-8 JSON processor options.

The C ABI exports:
- `card_scan_process(...) -> *mut CardScanResult`
- `card_scan_result_free(...)`

`card_scan_process` never lets a Rust panic unwind across FFI. Callers must release every non-null result with `card_scan_result_free`.

Quadrilateral detection, candidate scoring, perspective correction, and Flutter platform packaging are intentionally deferred to the next v0.2 PRs.
