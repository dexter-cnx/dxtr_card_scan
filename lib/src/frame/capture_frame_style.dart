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
}
