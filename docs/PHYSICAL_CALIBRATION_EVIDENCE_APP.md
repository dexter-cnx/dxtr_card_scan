# Physical Calibration Evidence App

## Purpose

The calibration evidence app is a dedicated Flutter entrypoint for collecting the physical-device dataset required by `V0_3_QUALITY_EVIDENCE_PROTOCOL.md`.

It intentionally records measurements and artifacts only. It does not decide whether a capture is good, ready, or acceptable.

## Run

From `example/`:

```bash
flutter pub get
flutter run -t lib/calibration_evidence_main.dart
```

Use a physical Android or iOS device. The package camera flow does not provide useful physical calibration evidence on a simulator.

## Session workflow

1. Confirm or edit the automatically suggested device label.
2. Tap **Start new device session**.
3. Complete 3 captures for each scenario:
   - `good`
   - `blur`
   - `dark`
   - `bright`
   - `small-card`
   - `perspective`
   - `busy-background`
4. Read the scenario guide shown above the camera before each capture.
5. Optionally add notes for unusual physical conditions.
6. Review/confirm the rectified crop.
7. After all 21 required captures are stored, create the session ZIP.

The app persists unfinished sessions, so evidence collection can be resumed after restarting the app.

## Evidence layout

The app writes into its application Documents directory under:

```text
dxtr_card_scan_calibration/
  <session-id>/
    session.json
    README.txt
    samples/
      <scenario>_<timestamp>/
        original.<ext>
        cropped.<ext>
        processed.<ext>
        metadata.json
  exports/
    dxtr_card_scan_<device>_<session-id>.zip
```

`metadata.json` contains the device metadata, scenario, notes, source ROI, raw original quality measurements, and raw rectified-crop quality measurements.

## Android extraction

The app displays its resolved Documents path on screen. Android Studio **Device Explorer** can be used to copy the calibration folder or generated ZIP from the debuggable app sandbox.

The in-app ZIP is mainly a convenience so the evidence can be moved as one artifact.

## iPhone extraction

The preferred iPhone flow is in-app export:

1. Finish the required matrix.
2. Tap **Create & Share ZIP**.
3. In the iOS share sheet choose **Save to Files**, **AirDrop**, or another destination.

The app uses the native iOS share sheet through `share_plus`, which wraps `UIActivityViewController`; sharing files is supported on iOS. This does not require making the whole app Documents directory visible in Files.

For development/debug recovery, Xcode can also download the app container from **Devices and Simulators** for an installed development build and the session data can be recovered from the application Documents directory.

### Optional Files-app visibility

If we later commit a standalone iOS host for this evidence app and want its Documents directory exposed directly in Files, add these keys to that host's `Info.plist`:

```xml
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

That is optional for the current flow because **Create & Share ZIP → Save to Files** already provides a controlled export path.

## Dataset rule

Do not change quality metric formulas midway through one calibration dataset. A metric-formula change starts a new dataset/version. Do not derive thresholds from one device or one card.
