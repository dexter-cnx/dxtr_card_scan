import 'package:flutter/material.dart';

import '../crop/image_crop_style.dart';
import '../frame/capture_frame_style.dart';

/// Theme extension shared by Camera capture and Gallery crop surfaces.
class DxtrCardScanTheme extends ThemeExtension<DxtrCardScanTheme> {
  const DxtrCardScanTheme({
    this.captureFrameStyle = const CaptureFrameStyle(),
    this.imageCropStyle = const ImageCropStyle(),
  });

  final CaptureFrameStyle captureFrameStyle;
  final ImageCropStyle imageCropStyle;

  @override
  DxtrCardScanTheme copyWith({
    CaptureFrameStyle? captureFrameStyle,
    ImageCropStyle? imageCropStyle,
  }) {
    return DxtrCardScanTheme(
      captureFrameStyle: captureFrameStyle ?? this.captureFrameStyle,
      imageCropStyle: imageCropStyle ?? this.imageCropStyle,
    );
  }

  @override
  DxtrCardScanTheme lerp(
    covariant ThemeExtension<DxtrCardScanTheme>? other,
    double t,
  ) {
    if (other is! DxtrCardScanTheme) return this;
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
    );
  }

  /// Resolves the nearest package theme or falls back to defaults.
  static DxtrCardScanTheme of(BuildContext context) {
    return Theme.of(context).extension<DxtrCardScanTheme>() ??
        const DxtrCardScanTheme();
  }
}
