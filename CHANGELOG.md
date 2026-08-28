# Changelog

All notable package changes are recorded here.

## Unreleased — 1.0 preparation

### Added

- Camera, Gallery, and unified Camera + Gallery capture surfaces.
- Configurable capture frames, orientation policies, controls, labels, and themes.
- Rust-backed card detection, perspective correction, preprocessing, JPEG/PNG encoding, and quality analysis.
- Capture profiles for `manual`, `ocr`, `fast`, and `archival` processing goals.
- Optional capture quality metadata and live corner-confidence feedback.
- Platform-neutral host-injected native scanner fallback with multi-page support.
- `CardTemplate` normalized regions and corrected-image region extraction.
- Separate `dxtr_card_scan_advanced.dart` barrel for supported low-level live/orchestration contracts.
- Android/iOS/macOS host-build validation matrix and reproducible Rust processor benchmark harness.

### Changed

- The root `dxtr_card_scan.dart` barrel is now the primary 1.x compatibility surface.
- Low-level live capture orchestration moved out of the primary barrel into `dxtr_card_scan_advanced.dart`.
- The standard example now demonstrates the recommended primary integration flow and keeps calibration tooling separate.

### Release gates still open

- Fresh physical Android/iOS validation for the 1.0 platform gate.
- Representative physical calibration evidence for geometry, stability, glare, perspective/alignment, and auto-capture readiness thresholds.

Automatic shutter dispatch remains opt-in; built-in capture profiles keep it disabled until calibration evidence supports production defaults.

## 0.1.0-dev.1

- Initial package scaffold and capture/geometry foundation.
