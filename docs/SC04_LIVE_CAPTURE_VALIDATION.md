# SC-04 Live Capture Physical Validation

Use this checklist before enabling a `liveStreamTransformResolver` state in production.

## Required matrix

For each supported Android/iOS device and camera:

- portrait up at minimum zoom
- landscape left at minimum zoom
- landscape right at minimum zoom
- front-camera states only if the product supports them

Zoomed stream analysis remains disabled until preview-to-stream crop evidence is collected separately.

## Evidence per state

1. Render a capture frame with asymmetric markers or a deliberately off-center target.
2. Record the active `CameraDescription`, `DeviceOrientation`, stream width/height and selected `CapturedImageTransform`.
3. Save a stream-frame analysis ROI image and a still-capture crop from the same physical alignment.
4. Verify left/right and top/bottom correspondence; a centered symmetric card alone is not sufficient to prove mirroring or quarter-turn direction.
5. Repeat after rotating away from and back to the state to catch stale orientation metadata.
6. Repeat capture after a live-analysis frame is already in flight to validate stream-stop/still-capture exclusivity.
7. Record pass/fail plus device/OS/plugin versions with the evidence bundle.

Only return a non-null transform from `liveStreamTransformResolver` for states supported by collected evidence. Unknown states must return `null`.

## End-to-end auto-capture gate

After geometry evidence passes, enable `CardAutoCaptureConfig.enabled` only for calibration runs. Verify stability gating, one-shot shutter dispatch, processing/confirmation stream pause, retake restart and cooldown behavior before changing any production default.
