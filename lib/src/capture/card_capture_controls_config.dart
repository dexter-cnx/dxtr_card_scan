/// Visibility configuration for the built-in camera controls.
class CardCaptureControlsConfig {
  const CardCaptureControlsConfig({
    this.showBack = true,
    this.showFlash = true,
    this.showTorch = true,
    this.showZoom = true,
    this.showShutter = true,
  });

  final bool showBack;
  final bool showFlash;
  final bool showTorch;
  final bool showZoom;
  final bool showShutter;
}
