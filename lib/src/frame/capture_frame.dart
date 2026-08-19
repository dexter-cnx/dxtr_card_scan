import 'dart:ui';

import '../geometry/normalized_rect.dart';

/// Declarative capture-frame geometry.
class CaptureFrame {
  const CaptureFrame({
    this.aspectRatio,
    this.widthFactor = 0.88,
    this.fixedSize,
    this.normalizedRect,
  }) : assert(widthFactor > 0 && widthFactor <= 1),
       assert(aspectRatio == null || aspectRatio > 0),
       assert(
         (fixedSize == null ? 0 : 1) + (normalizedRect == null ? 0 : 1) <= 1,
         'fixedSize and normalizedRect are mutually exclusive',
       );

  /// Common ID-1 card aspect ratio (85.60 mm x 53.98 mm).
  const CaptureFrame.id1({this.widthFactor = 0.88})
      : aspectRatio = 85.60 / 53.98,
        fixedSize = null,
        normalizedRect = null;

  final double? aspectRatio;
  final double widthFactor;
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
      final width = viewport.width * widthFactor;
      final ratio = aspectRatio ?? 85.60 / 53.98;
      size = Size(width, width / ratio);
    }

    return Rect.fromCenter(
      center: Offset(viewport.width / 2, viewport.height / 2),
      width: size.width,
      height: size.height,
    );
  }
}
