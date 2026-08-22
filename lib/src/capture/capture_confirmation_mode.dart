/// Controls whether the built-in capture flow pauses after rectification.
enum CaptureConfirmationMode {
  /// Continue directly from rectified crop to final processing.
  none,

  /// Show the rectified crop and let the user Retake or Use it.
  afterCrop,
}
