import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Visual style for camera controls used by host/example camera UIs.
///
/// Color fields are nullable on purpose. When omitted, the host should resolve
/// them from its Material [ColorScheme].
class CameraControlsStyle {
  const CameraControlsStyle({
    this.shutterSize = 80,
    this.shutterShape = const CircleBorder(),
    this.shutterBackgroundColor,
    this.shutterForegroundColor,
    this.shutterBorderColor,
    this.shutterBorderWidth = 0,
    this.controlBackgroundColor,
    this.controlForegroundColor,
    this.activeControlBackgroundColor,
    this.activeControlForegroundColor,
    this.zoomBadgeBackgroundColor,
    this.zoomBadgeForegroundColor,
  })  : assert(shutterSize > 0),
        assert(shutterBorderWidth >= 0);

  final double shutterSize;
  final ShapeBorder shutterShape;
  final Color? shutterBackgroundColor;
  final Color? shutterForegroundColor;
  final Color? shutterBorderColor;
  final double shutterBorderWidth;

  /// Background shared by Back / Flash / Torch when inactive.
  final Color? controlBackgroundColor;

  /// Foreground shared by Back / Flash / Torch when inactive.
  final Color? controlForegroundColor;

  /// Background for active controls such as Torch-on or Flash-on.
  final Color? activeControlBackgroundColor;

  /// Foreground for active controls such as Torch-on or Flash-on.
  final Color? activeControlForegroundColor;

  final Color? zoomBadgeBackgroundColor;
  final Color? zoomBadgeForegroundColor;

  CameraControlsStyle copyWith({
    double? shutterSize,
    ShapeBorder? shutterShape,
    Color? shutterBackgroundColor,
    Color? shutterForegroundColor,
    Color? shutterBorderColor,
    double? shutterBorderWidth,
    Color? controlBackgroundColor,
    Color? controlForegroundColor,
    Color? activeControlBackgroundColor,
    Color? activeControlForegroundColor,
    Color? zoomBadgeBackgroundColor,
    Color? zoomBadgeForegroundColor,
  }) {
    return CameraControlsStyle(
      shutterSize: shutterSize ?? this.shutterSize,
      shutterShape: shutterShape ?? this.shutterShape,
      shutterBackgroundColor:
          shutterBackgroundColor ?? this.shutterBackgroundColor,
      shutterForegroundColor:
          shutterForegroundColor ?? this.shutterForegroundColor,
      shutterBorderColor: shutterBorderColor ?? this.shutterBorderColor,
      shutterBorderWidth: shutterBorderWidth ?? this.shutterBorderWidth,
      controlBackgroundColor:
          controlBackgroundColor ?? this.controlBackgroundColor,
      controlForegroundColor:
          controlForegroundColor ?? this.controlForegroundColor,
      activeControlBackgroundColor:
          activeControlBackgroundColor ?? this.activeControlBackgroundColor,
      activeControlForegroundColor:
          activeControlForegroundColor ?? this.activeControlForegroundColor,
      zoomBadgeBackgroundColor:
          zoomBadgeBackgroundColor ?? this.zoomBadgeBackgroundColor,
      zoomBadgeForegroundColor:
          zoomBadgeForegroundColor ?? this.zoomBadgeForegroundColor,
    );
  }

  static CameraControlsStyle lerp(
    CameraControlsStyle a,
    CameraControlsStyle b,
    double t,
  ) {
    return CameraControlsStyle(
      shutterSize: lerpDouble(a.shutterSize, b.shutterSize, t)!,
      shutterShape:
          ShapeBorder.lerp(a.shutterShape, b.shutterShape, t) ?? b.shutterShape,
      shutterBackgroundColor:
          Color.lerp(a.shutterBackgroundColor, b.shutterBackgroundColor, t),
      shutterForegroundColor:
          Color.lerp(a.shutterForegroundColor, b.shutterForegroundColor, t),
      shutterBorderColor:
          Color.lerp(a.shutterBorderColor, b.shutterBorderColor, t),
      shutterBorderWidth:
          lerpDouble(a.shutterBorderWidth, b.shutterBorderWidth, t)!,
      controlBackgroundColor:
          Color.lerp(a.controlBackgroundColor, b.controlBackgroundColor, t),
      controlForegroundColor:
          Color.lerp(a.controlForegroundColor, b.controlForegroundColor, t),
      activeControlBackgroundColor: Color.lerp(
        a.activeControlBackgroundColor,
        b.activeControlBackgroundColor,
        t,
      ),
      activeControlForegroundColor: Color.lerp(
        a.activeControlForegroundColor,
        b.activeControlForegroundColor,
        t,
      ),
      zoomBadgeBackgroundColor: Color.lerp(
        a.zoomBadgeBackgroundColor,
        b.zoomBadgeBackgroundColor,
        t,
      ),
      zoomBadgeForegroundColor: Color.lerp(
        a.zoomBadgeForegroundColor,
        b.zoomBadgeForegroundColor,
        t,
      ),
    );
  }
}
