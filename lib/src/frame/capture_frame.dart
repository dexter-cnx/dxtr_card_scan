import 'package:flutter/painting.dart';

import '../geometry/normalized_rect.dart';

/// Declarative capture-frame geometry.
class CaptureFrame {
  const CaptureFrame({
    this.aspectRatio,
    this.widthFactor = 0.88,
    this.maxHeightFactor = 0.82,
    this.fixedSize,
    this.normalizedRect,
    this.alignment,
    this.alignmentPadding = EdgeInsets.zero,
  })  : assert(widthFactor > 0 && widthFactor <= 1),
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
    this.alignment,
    this.alignmentPadding = EdgeInsets.zero,
  })  : aspectRatio = 85.60 / 53.98,
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

  /// Position of an automatically sized or fixed-size frame in the viewport.
  ///
  /// `null` preserves the historical behavior and resolves to
  /// [Alignment.center]. This value is ignored when [normalizedRect] is used,
  /// because that rectangle already defines both size and position.
  final Alignment? alignment;

  /// Insets applied to the viewport before [alignment] is resolved.
  ///
  /// For example, `Alignment.topCenter` with
  /// `EdgeInsets.only(top: 32)` keeps the frame 32 logical pixels away from
  /// the top edge. Ignored when [normalizedRect] is used.
  final EdgeInsets alignmentPadding;

  Rect resolve(Size viewport) {
    if (normalizedRect case final normalized?) {
      return normalized.toRect(viewport);
    }

    final viewportRect = Offset.zero & viewport;
    final alignmentRect = alignmentPadding.deflateRect(viewportRect);
    final availableSize = alignmentRect.size;

    final Size size;
    if (fixedSize case final fixed?) {
      size = fixed;
    } else {
      final ratio = aspectRatio ?? 85.60 / 53.98;
      var width = availableSize.width * widthFactor;
      var height = width / ratio;
      final maxHeight = availableSize.height * maxHeightFactor;
      if (height > maxHeight) {
        height = maxHeight;
        width = height * ratio;
      }
      size = Size(width, height);
    }

    return (alignment ?? Alignment.center).inscribe(size, alignmentRect);
  }
}
