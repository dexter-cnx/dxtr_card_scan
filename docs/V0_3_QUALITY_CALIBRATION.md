# v0.3 Quality Calibration

## Goal

Collect representative measurements before defining any quality/readiness threshold.

The calibration harness intentionally reports values only. It does not classify a capture as good, bad, ready, or rejected.

## Example workflow

Run the example on a physical device and complete either Camera or Gallery capture. After the scan is confirmed, the example opens the quality calibration page and analyzes two stages:

1. **Original capture** — used as the primary evidence for blur, exposure, card coverage, and detection confidence.
2. **Rectified crop** — diagnostic evidence for how crop/perspective correction changes the measured image quality.

Analysis runs in a background isolate so the example UI does not perform synchronous native quality analysis on the UI isolate.

Use **Copy calibration values** to copy a stable text snapshot for an evidence log.

## Evidence matrix

Collect multiple samples for each relevant condition rather than tuning against one image.

| Dimension | Suggested cases |
| --- | --- |
| Source | Camera, Gallery |
| Focus | sharp, mildly blurred, strongly blurred |
| Exposure | normal, dark, bright/backlit |
| Card size | small, expected framing, nearly full frame |
| Card angle | frontal, mild perspective, stronger perspective |
| Background | plain, textured, low color contrast, high color contrast |
| Device | each supported physical-device family used for validation |

For Camera calibration, prefer several captures of the same card/scene while changing only one variable at a time where practical.

## Evidence record

Each copied record contains the source plus original and rectified metrics:

- blur score and raw Laplacian variance
- exposure score, mean luma, dark fraction, bright fraction
- card coverage
- detection confidence

Keep the image/condition label next to the copied values in the evidence log. Do not infer thresholds from a single sample.

## Threshold policy

Thresholds remain deferred until the evidence set demonstrates useful separation between acceptable and unacceptable captures. Any future readiness policy should be documented separately from the raw measurement API so measurement semantics remain stable even if policy values change.
