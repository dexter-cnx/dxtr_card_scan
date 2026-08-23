# v0.3 Quality Analysis

## Goal

Add deterministic, measurement-only capture quality analysis before any live auto-capture policy is introduced.

## Public measurements

`CardScanQualityAnalysis` exposes:

- `blur.laplacianVariance` — raw Laplacian variance.
- `blur.score` — normalized `[0, 1]` sharpness measurement; higher means more edge detail.
- `exposure.meanLuma` — normalized mean luminance.
- `exposure.darkFraction` — fraction of near-black pixels.
- `exposure.brightFraction` — fraction of near-white pixels.
- `exposure.score` — normalized exposure-quality measurement.
- `cardCoverage` — normalized detected-card area within the analysis image.
- `detectionConfidence` — hybrid detector total confidence.

## API

```dart
final analysis = processor.analyzeQualityBytes(bytes);
final fromFile = await processor.analyzeQualityFile(path);
```

The Rust ABI symbol is `card_scan_analyze_quality`.

## Calibration harness

The integrated example reports measurements for the original capture and the rectified crop after Camera or Gallery completion. Analysis is performed in a background isolate and the values can be copied as a stable text record for calibration evidence.

See `docs/V0_3_QUALITY_CALIBRATION.md` for the evidence matrix and threshold policy.

## Policy boundary

v0.3 measurements do not define `good`, `bad`, `ready`, or auto-capture thresholds. Calibration and readiness policy belong after evidence is collected from representative devices, lighting conditions, card types, and motion/blur cases.

## Performance boundary

Quality analysis downsizes the longest image edge to at most 960 pixels before computing metrics. Final image processing remains unchanged and continues to use the validated v0.2 processing path.
