import 'package:flutter/material.dart';

/// Default visual treatment for the capture frame.
class CaptureFrameStyle {
  const CaptureFrameStyle({
    this.borderColor = Colors.white,
    this.borderWidth = 2,
    this.cornerRadius = 12,
    this.overlayColor = const Color(0x88000000),
  });

  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;
  final Color overlayColor;

  CaptureFrameStyle copyWith({
    Color? borderColor,
    double? borderWidth,
    double? cornerRadius,
    Color? overlayColor,
  }) {
    return CaptureFrameStyle(
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      overlayColor: overlayColor ?? this.overlayColor,
    );
  }

  static CaptureFrameStyle lerp(
    CaptureFrameStyle a,
    CaptureFrameStyle b,
    double t,
  ) {
    return CaptureFrameStyle(
      borderColor: Color.lerp(a.borderColor, b.borderColor, t)!,
      borderWidth: a.borderWidth + (b.borderWidth - a.borderWidth) * t,
      cornerRadius: a.cornerRadius + (b.cornerRadius - a.cornerRadius) * t,
      overlayColor: Color.lerp(a.overlayColor, b.overlayColor, t)!,
    );
  }
}
