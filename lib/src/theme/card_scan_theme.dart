import 'package:flutter/material.dart';

import '../crop/image_crop_style.dart';
import '../frame/capture_frame_style.dart';
import 'camera_controls_style.dart';

/// Theme extension shared by Camera capture and Gallery crop surfaces.
class CardScanTheme extends ThemeExtension<CardScanTheme> {
  const CardScanTheme({
    this.captureFrameStyle = const CaptureFrameStyle(),
    this.imageCropStyle = const ImageCropStyle(),
    this.cameraControlsStyle = const CameraControlsStyle(),
  });

  final CaptureFrameStyle captureFrameStyle;
  final ImageCropStyle imageCropStyle;
  final CameraControlsStyle cameraControlsStyle;

  @override
  CardScanTheme copyWith({
    CaptureFrameStyle? captureFrameStyle,
    ImageCropStyle? imageCropStyle,
    CameraControlsStyle? cameraControlsStyle,
  }) {
    return CardScanTheme(
      captureFrameStyle: captureFrameStyle ?? this.captureFrameStyle,
      imageCropStyle: imageCropStyle ?? this.imageCropStyle,
      cameraControlsStyle: cameraControlsStyle ?? this.cameraControlsStyle,
    );
  }

  @override
  CardScanTheme lerp(
    covariant CardScanTheme? other,
    double t,
  ) {
    if (other == null) return this;
    return CardScanTheme(
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
  static CardScanTheme of(BuildContext context) {
    return Theme.of(context).extension<CardScanTheme>() ??
        const CardScanTheme();
  }
}
