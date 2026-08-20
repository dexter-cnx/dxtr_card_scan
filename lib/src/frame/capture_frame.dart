import 'dart:ui';

import '../geometry/normalized_rect.dart';

/// Declarative capture-frame geometry.
class CaptureFrame {
  const CaptureFrame({
    this.aspectRatio,
    this.widthFactor = 0.88,
    this.maxHeightFactor = 0.82,
    this.fixedSize,
    this.normalizedRect,
  }) : assert(widthFactor > 0 && widthFactor <= 1),
       assert(maxHeightFactor > 0 && maxHeightFactor <= 1),
       assert(aspectRatio == null || aspectRatio > 0),
       assert(
         (fixedSize == null ? 0 : 1) + (normalizedRect == null ? 0 : 1) <= 1,
         'fixedSize and normalizedRect are mutually exclusive',
       );

  /// Common ID-1 card aspect ratio (85.60 mm x 53.98 mm).
  const CaptureFrame.id1({
    this.widthFactor = 0.88,
    this.maxHeightFactor = 0.82,
  }) : aspectRatio = 85.60 / 53.98,
       fixedSize = null,
       normalizedRect = null;

  final double? aspectRatio;
  final double widthFactor;

  /// Maximum fraction of the viewport height used by an automatically sized
  /// frame. This prevents wide landscape viewports from producing a frame
  /// whose height extends beyond the visible capture surface.
  final double maxHeightFactor;

  final Size? fixedSize;
  final NormalizedRect? normalizedRect;

  Rect resolve(Size viewport) {
    if (normalizedRect case final normalized?) {
      return normalized.toRect(viewport);
    }

    final Size size;
    if (fixedSize case final fixed?) {
      size = fixed;
    } else {
      final ratio = aspectRatio ?? 85.60 / 53.98;
      var width = viewport.width * widthFactor;
      var height = width / ratio;
      final maxHeight = viewport.height * maxHeightFactor;
      if (height > maxHeight) {
        height = maxHeight;
        width = height * ratio;
      }
      size = Size(width, height);
    }

    return Rect.fromCenter(
      center: Offset(viewport.width / 2, viewport.height / 2),
      width: size.width,
      height: size.height,
    );
  }
}
