import 'package:flutter/widgets.dart';

/// Controls which viewport orientations may capture.
enum CaptureOrientationPolicy {
  /// Capture is allowed in portrait and landscape.
  any,

  /// Capture is allowed only when the viewport is portrait.
  portraitOnly,

  /// Capture is allowed only when the viewport is landscape.
  landscapeOnly;

  /// Whether [orientation] is accepted by this policy.
  bool allows(Orientation orientation) {
    return switch (this) {
      CaptureOrientationPolicy.any => true,
      CaptureOrientationPolicy.portraitOnly =>
        orientation == Orientation.portrait,
      CaptureOrientationPolicy.landscapeOnly =>
        orientation == Orientation.landscape,
    };
  }
}
