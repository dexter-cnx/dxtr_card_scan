# Project Handoff

Last updated: 2026-08-26

## Project

Repository: `dexter-cnx/dxtr_card_scan`

`dxtr_card_scan` is an OCR-engine-agnostic Flutter/Dart SDK for card capture plus deterministic Rust preprocessing. Flutter owns camera/UI/preview geometry. Rust owns deterministic raster processing.

## Architecture rules

1. Core does not embed an OCR engine.
2. Rust does not own camera lifecycle/UI.
3. Preview/frame geometry is explicit and normalized before processing.
4. Rotation/mirroring is explicit; live raw frames must never guess orientation.
5. Camera/Gallery default behavior is package-owned; hosts configure rather than reimplement.
6. CPU-heavy decode/native work stays off the Flutter UI isolate.
7. Live analysis and final capture share the SC-02 geometry contract.
8. Temporal stability and auto-capture are deterministic policy layers.
9. Auto capture is opt-in and disabled by default.
10. Raw `CameraImage` planes are converted to an encoded analysis ROI before entering the Rust ABI.

## Merged Smart Capture work

- SC-00 unified Camera/Gallery entry — PR #14, `062fc5dcb5deaf8d61b3649eb567ff0cae4e2b4c`
- SC-01 advisory quality model — PR #15, `50040812d27ceb504b85589a871f3ce9239592d2`
- SC-02 frame-to-sensor geometry — PR #16, `1d324af5a2264017bf5cb96e3ee3ce3c5cd33d10`
- SC-03 blur + temporal stability — PR #17, `822bacd31832307dda27c4ea70115d441ab0846f`
- SC-04 quality-gated auto-capture policy — PR #18, `e10bdbe282ce9476852520bd71421033da0b8888`
- SC-04 live capture coordinator — PR #19, `2daf3d0bcac573e98806511922e1282a597a8667`

Current branch: `feature/sc04-camera-image-adapter`.

## Smart Capture contracts

### SC-01 quality

`CardCaptureQualityAssessment` interprets blur, exposure, coverage and detection confidence. Aggregate score remains advisory; non-zero score gating is opt-in until physical calibration supports it.

### SC-02 geometry

`CameraGeometryMapper` maps viewport/frame geometry to raw sensor/image coordinates while accounting for preview fit, crop/zoom, rotation and mirroring. Live analysis must use this mapping before ROI extraction.

### SC-03 stability

`CardCaptureStabilityTracker` gates on sharpness/detection confidence and tracks quad corner displacement plus card-coverage drift. Cyclic detector corner ordering is aligned before displacement comparison.

### SC-04 policy + coordinator

`CardAutoCapturePolicy` exposes `searching`, `detected`, `ready`, `cooldown`; it never invokes the shutter itself. `CardLiveCaptureCoordinator` throttles accepted samples, composes quality + stability + policy, dispatches through a package-owned capture delegate, prevents re-entrant shutter dispatch, and starts cooldown only when capture is actually dispatched.

Throttle recovers from backward wall-clock corrections instead of freezing until wall time catches up.

### SC-04 raw CameraImage adapter

Current branch adds `CardCameraImageAdapter` plus isolate-safe `CardCameraFrame`/`CardCameraFramePlane` DTOs.

Supported raw formats:
- YUV420 with independent row/pixel strides
- BGRA8888 with row stride

The adapter:
1. copies `CameraImage` planes into an isolate-safe DTO
2. decodes the raw frame deterministically
3. crops the normalized raw-frame ROI
4. JPEG-encodes only that ROI for the existing Rust quality/detection ABI

The adapter deliberately does **not** rotate or mirror. Its ROI is already expected to be in raw-frame coordinates according to the SC-02 contract. Android/iOS stream orientation and preview-to-stream mapping still require physical-device validation before automatic live streaming is enabled by default.

## Important validation lessons

1. Camera JPEG/display orientation must be normalized before final ROI mapping.
2. Live `CameraImage` bytes are raw YUV/BGRA, not encoded image bytes; never send raw planes directly to Rust decode APIs.
3. YUV row stride and chroma pixel stride must be honored.
4. Cyclic quad ordering must not create false stability motion.
5. Cooldown starts only after a shutter dispatch is accepted.
6. Live geometry must account for preview fit, crop/zoom, rotation and mirroring explicitly.

## Next milestone

Finish CI/review for the raw CameraImage adapter. Then wire a throttled `startImageStream()` path in `CardCaptureView` that:

`CameraImage -> CardCameraImageAdapter -> mapped ROI JPEG -> Rust quality/detection -> CardLiveCaptureCoordinator -> package shutter`

Keep this opt-in until Android/iOS physical geometry/orientation evidence is recorded.

## Documentation policy

Keep `docs/PROJECT_HANDOFF.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/ROADMAP.md` synchronized for material capture/geometry/native-processing changes.
