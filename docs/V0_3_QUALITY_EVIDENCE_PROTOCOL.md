# v0.3 Quality Evidence Protocol

## Purpose

Collect comparable physical-device evidence for the measurement-only quality API before introducing any readiness threshold or auto-capture policy.

This protocol is intentionally descriptive. It records raw measurements and observed capture conditions; it does not classify a sample as `ready`, `good`, or `bad` in code.

## Record one sample per capture

For every Camera or Gallery sample, record:

- source: Camera or Gallery
- device label: human-readable device/model label
- scenario: short stable identifier such as `good`, `blur`, `dark`, `bright`, `small-card`, `perspective`, or `busy-background`
- notes: optional free-text context
- original orientation-normalized measurements
- rectified-crop measurements

The example calibration page emits a copyable record in this shape.

## Minimum evidence matrix

Collect at least 3 samples for each scenario on each representative physical device:

| Scenario | Intent |
| --- | --- |
| `good` | steady capture, normal indoor light, card fills guide |
| `blur` | deliberate hand motion / defocus |
| `dark` | underexposed or dim environment |
| `bright` | strong light / clipped highlights |
| `small-card` | card occupies clearly less of the frame |
| `perspective` | noticeable but usable perspective angle |
| `busy-background` | high-contrast or card-like background |

Where practical, repeat the same source image through Gallery to separate camera acquisition effects from detector/measurement effects.

## Calibration rules

1. Do not change metric formulas while evidence is being collected. A formula change starts a new calibration dataset/version.
2. Do not derive threshold values from a single device or a single card.
3. Keep raw measurements. Do not round stored values to UI precision if a machine-readable dataset is later introduced.
4. Treat `blur.score`, `exposure.score`, `cardCoverage`, and `detectionConfidence` as independent signals until evidence shows that a combined policy is justified.
5. Record false positives explicitly, especially high detection confidence on a non-card or background region.

## Exit criteria for threshold design

Threshold policy work may start after the dataset includes representative Android and iOS physical-device samples covering all scenarios above, with enough repeated captures to see normal within-scenario variation.

The first threshold proposal should live in documentation/tests before it is connected to live capture. v0.4 auto-capture remains out of scope until that policy is validated.
