import 'dart:ui';

import 'package:flutter/painting.dart';

import 'captured_image_transform.dart';
import 'normalized_rect.dart';

/// Maps capture-frame geometry between a `BoxFit.cover` preview and a
/// captured image.
class PreviewGeometry {
  const PreviewGeometry({
    required this.viewportSize,
    required this.imageSize,
    this.transform = const CapturedImageTransform(),
  });

  final Size viewportSize;
  final Size imageSize;
  final CapturedImageTransform transform;

  /// Maps a viewport-space rectangle to the orientation-normalized image used
  /// by the preview.
  Rect viewportRectToDisplayedImage(Rect viewportRect) {
    final displayedSize = transform.orientedSize(imageSize);
    if (viewportSize.isEmpty || displayedSize.isEmpty) {
      throw StateError('viewportSize and imageSize must be non-empty.');
    }

    final fitted = applyBoxFit(BoxFit.cover, displayedSize, viewportSize);
    final source = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & displayedSize,
    );
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & viewportSize,
    );

    final scaleX = source.width / destination.width;
    final scaleY = source.height / destination.height;

    return Rect.fromLTRB(
      source.left + (viewportRect.left - destination.left) * scaleX,
      source.top + (viewportRect.top - destination.top) * scaleY,
      source.left + (viewportRect.right - destination.left) * scaleX,
      source.top + (viewportRect.bottom - destination.top) * scaleY,
    ).intersect(Offset.zero & displayedSize);
  }

  /// Maps a viewport-space rectangle to raw captured-image pixel coordinates.
  Rect viewportRectToImage(Rect viewportRect) {
    final displayedSize = transform.orientedSize(imageSize);
    final displayed = NormalizedRect.fromRect(
      viewportRectToDisplayedImage(viewportRect),
      displayedSize,
    );
    return transform.displayedToRaw(displayed).toRect(imageSize);
  }

  /// Maps a viewport-space rectangle to normalized raw captured-image
  /// coordinates, suitable for crossing the future Rust boundary.
  NormalizedRect viewportRectToNormalizedImage(Rect viewportRect) {
    return NormalizedRect.fromRect(viewportRectToImage(viewportRect), imageSize);
  }
}
