import 'package:flutter/material.dart';

/// Visual treatment for [ImageCropView].
class ImageCropStyle {
  const ImageCropStyle({
    this.overlayColor = const Color(0x88000000),
    this.borderColor = Colors.white,
    this.borderWidth = 2,
    this.handleColor = Colors.white,
    this.handleBorderColor = Colors.black54,
    this.handleSize = 16,
    this.handleHitSize = 36,
  });

  final Color overlayColor;
  final Color borderColor;
  final double borderWidth;
  final Color handleColor;
  final Color handleBorderColor;
  final double handleSize;
  final double handleHitSize;

  ImageCropStyle copyWith({
    Color? overlayColor,
    Color? borderColor,
    double? borderWidth,
    Color? handleColor,
    Color? handleBorderColor,
    double? handleSize,
    double? handleHitSize,
  }) {
    return ImageCropStyle(
      overlayColor: overlayColor ?? this.overlayColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      handleColor: handleColor ?? this.handleColor,
      handleBorderColor: handleBorderColor ?? this.handleBorderColor,
      handleSize: handleSize ?? this.handleSize,
      handleHitSize: handleHitSize ?? this.handleHitSize,
    );
  }

  static ImageCropStyle lerp(ImageCropStyle a, ImageCropStyle b, double t) {
    return ImageCropStyle(
      overlayColor: Color.lerp(a.overlayColor, b.overlayColor, t)!,
      borderColor: Color.lerp(a.borderColor, b.borderColor, t)!,
      borderWidth: lerpDouble(a.borderWidth, b.borderWidth, t),
      handleColor: Color.lerp(a.handleColor, b.handleColor, t)!,
      handleBorderColor:
          Color.lerp(a.handleBorderColor, b.handleBorderColor, t)!,
      handleSize: lerpDouble(a.handleSize, b.handleSize, t),
      handleHitSize: lerpDouble(a.handleHitSize, b.handleHitSize, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
