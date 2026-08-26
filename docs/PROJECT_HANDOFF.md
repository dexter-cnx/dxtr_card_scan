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
11. Live stream callbacks must apply backpressure before copying/decoding frames.
12. Still capture owns the camera exclusively: live streaming stops before `takePicture()` and remains stopped through processing/confirmation.

## Merged Smart Capture work

- SC-00 unified Camera/Gallery entry — PR #14, `062fc5dcb5deaf8d61b3649eb567ff0cae4e2b4c`
- SC-01 advisory quality model — PR #15, `50040812d27ceb504b85589a871f3ce9239592d2`
- SC-02 frame-to-sensor geometry — PR #16, `1d324af5a2264017bf5cb96e3ee3ce3c5cd33d10`
- SC-03 blur + temporal stability — PR #17, `822bacd31832307dda27c4ea70115d441ab0846f`
- SC-04 quality-gated auto-capture policy — PR #18, `e10bdbe282ce9476852520bd71421033da0b8888`
- SC-04 live capture coordinator — PR #19, `2daf3d0bcac573e98806511922e1282a597a8667`
- SC-04 raw CameraImage adapter — PR #20, `71eaf99e437c243aa1069d863930b7d376a97e21`
- SC-04 worker-isolate live frame analysis — PR #21, `c6b6150df886070eacc3086443c8359fb014eebc`
- SC-04 live camera stream session — PR #22, `b0efed3684ab88ebda12170f909a71d5416c8af9`

Current branch: `feature/sc04-card-capture-view-integration`.

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

`CardCameraImageAdapter` plus isolate-safe `CardCameraFrame`/`CardCameraFramePlane` DTOs support BGRA8888, planar YUV420 and bi-planar YUV420 while honoring row/pixel strides. ROI bounds are quantized before conversion so only the requested raw-frame ROI is decoded and JPEG-encoded for Rust analysis.

The adapter deliberately does **not** rotate or mirror. Its ROI is expected to already be in raw-frame coordinates according to the SC-02 contract.

### SC-04 live frame analyzer

`CardLiveFrameAnalyzer` accepts a copied `CardCameraFrame` plus mapped `NormalizedRect`, then runs ROI conversion/JPEG encoding and one combined Rust quality/detection call on a worker isolate. It returns `CardLiveAnalysisSample` ready for `CardLiveCaptureCoordinator` without blocking the camera/UI isolate.

### SC-04 live camera session

`CardLiveCameraSession` owns `CameraController.startImageStream()` lifecycle and enforces interval gating plus a single-frame-in-flight rule before expensive plane copies and isolate work. Stop/restart generations invalidate stale analysis results, stopping resets coordinator state, and backpressure remains active until stale analysis futures actually settle.

### SC-04 CardCaptureView integration

`CardCaptureView` now owns the live coordinator/session and package shutter delegate. Live streaming is opt-in through `liveStreamTransformResolver`; the resolver must return an explicit `CapturedImageTransform` for the active camera/device orientation or `null` when that state is not validated.

For accepted live frames the view resolves its current capture-frame rectangle through `CameraGeometryMapper` using the raw `CameraImage` dimensions. The live pipeline is:

`CameraImage -> CardCaptureView SC-02 mapping -> CardLiveCameraSession -> CardCameraImageAdapter -> CardLiveFrameAnalyzer -> CardLiveCaptureCoordinator -> package shutter`

Still capture calls `stop()` before `takePicture()`. Streaming remains stopped during preprocessing, rectification and confirmation. Retake or a completed/error capture returns to the camera surface and restarts the session when configured.

Zoomed live analysis is intentionally skipped for now. The plugin/platform preview-to-stream crop relationship still needs physical evidence; final still capture zoom behavior is unchanged.

Android/iOS stream orientation and preview-to-stream mapping still require physical-device validation before automatic live streaming is enabled by default.

## Important validation lessons

1. Camera JPEG/display orientation must be normalized before final ROI mapping.
2. Live `CameraImage` bytes are raw YUV/BGRA, not encoded image bytes; never send raw planes directly to Rust decode APIs.
3. YUV row stride, luminance pixel stride, chroma pixel stride and bi-planar layouts must be honored.
4. Decode only the mapped ROI for live cadence; do not decode a full high-resolution frame before cropping.
5. Cyclic quad ordering must not create false stability motion.
6. Cooldown starts only after a shutter dispatch is accepted.
7. Live geometry must account for preview fit, crop/zoom, rotation and mirroring explicitly.
8. Throttle before copying camera planes and do not allow an unbounded frame-analysis queue.
9. Never run `takePicture()` concurrently with the analysis stream.
10. Unknown orientation/mirroring states must skip live analysis rather than fall back to guessed transforms.

## Next milestone

SC-04 code integration is complete after this PR. Remaining SC-04 work is evidence rather than another architecture layer:

1. collect preview-to-stream geometry evidence on physical Android/iOS devices across supported orientations;
2. validate or define zoom crop mapping before enabling zoomed live analysis;
3. run end-to-end physical auto-capture calibration and only then consider production defaults.

After evidence collection, proceed to SC-05 glare detection unless calibration exposes a geometry/lifecycle defect that needs a focused fix.

## Documentation policy

Keep `docs/PROJECT_HANDOFF.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/ROADMAP.md` synchronized for material capture/geometry/native-processing changes.
