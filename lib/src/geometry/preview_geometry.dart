import 'dart:ui';

import 'package:flutter/painting.dart';

import 'normalized_rect.dart';

/// Maps capture-frame geometry between a BoxFit.cover preview and source image.
class PreviewGeometry {
  const PreviewGeometry({required this.viewportSize, required this.imageSize});

  final Size viewportSize;
  final Size imageSize;

  Rect viewportRectToImage(Rect viewportRect) {
    if (viewportSize.isEmpty || imageSize.isEmpty) {
      throw StateError('viewportSize and imageSize must be non-empty.');
    }

    final fitted = applyBoxFit(BoxFit.cover, imageSize, viewportSize);
    final source = Alignment.center.inscribe(fitted.source, Offset.zero & imageSize);
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
    ).intersect(Offset.zero & imageSize);
  }

  NormalizedRect viewportRectToNormalizedImage(Rect viewportRect) {
    return NormalizedRect.fromRect(viewportRectToImage(viewportRect), imageSize);
  }
}
