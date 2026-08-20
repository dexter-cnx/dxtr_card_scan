import 'package:flutter/material.dart';

import '../crop/image_crop_style.dart';
import '../frame/capture_frame_style.dart';
import 'camera_controls_style.dart';

/// Theme extension shared by Camera capture and Gallery crop surfaces.
class DxtrCardScanTheme extends ThemeExtension<DxtrCardScanTheme> {
  const DxtrCardScanTheme({
    this.captureFrameStyle = const CaptureFrameStyle(),
    this.imageCropStyle = const ImageCropStyle(),
    this.cameraControlsStyle = const CameraControlsStyle(),
  });

  final CaptureFrameStyle captureFrameStyle;
  final ImageCropStyle imageCropStyle;
  final CameraControlsStyle cameraControlsStyle;

  @override
  DxtrCardScanTheme copyWith({
    CaptureFrameStyle? captureFrameStyle,
    ImageCropStyle? imageCropStyle,
    CameraControlsStyle? cameraControlsStyle,
  }) {
    return DxtrCardScanTheme(
      captureFrameStyle: captureFrameStyle ?? this.captureFrameStyle,
      imageCropStyle: imageCropStyle ?? this.imageCropStyle,
      cameraControlsStyle: cameraControlsStyle ?? this.cameraControlsStyle,
    );
  }

  @override
  DxtrCardScanTheme lerp(
    covariant DxtrCardScanTheme? other,
    double t,
  ) {
    if (other == null) return this;
    return DxtrCardScanTheme(
      captureFrameStyle: CaptureFrameStyle.lerp(
        captureFrameStyle,
        other.captureFrameStyle,
        t,
      ),
      imageCropStyle: ImageCropStyle.lerp(
        imageCropStyle,
        other.imageCropStyle,
        t,
      ),
      cameraControlsStyle: CameraControlsStyle.lerp(
        cameraControlsStyle,
        other.cameraControlsStyle,
        t,
      ),
    );
  }

  /// Resolves the nearest package theme or falls back to defaults.
  static DxtrCardScanTheme of(BuildContext context) {
    return Theme.of(context).extension<DxtrCardScanTheme>() ??
        const DxtrCardScanTheme();
  }
}
