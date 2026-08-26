import 'package:flutter/painting.dart';

import 'captured_image_transform.dart';
import 'normalized_rect.dart';

/// Maps viewport-space capture geometry into normalized raw sensor/image space.
///
/// [displayedCropRegion] is expressed in the orientation-normalized displayed
/// sensor space. It represents the effective crop used by preview composition,
/// including digital zoom or platform camera crop regions.
class CameraGeometryMapper {
  const CameraGeometryMapper({
    required this.viewportSize,
    required this.sensorSize,
    this.displayedCropRegion = const NormalizedRect(
      left: 0,
      top: 0,
      right: 1,
      bottom: 1,
    ),
    this.transform = const CapturedImageTransform(),
    this.fit = BoxFit.cover,
  });

  final Size viewportSize;
  final Size sensorSize;
  final NormalizedRect displayedCropRegion;
  final CapturedImageTransform transform;
  final BoxFit fit;

  /// Maps a viewport rectangle to normalized coordinates in the raw sensor.
  NormalizedRect viewportRectToSensor(Rect viewportRect) {
    if (viewportSize.isEmpty || sensorSize.isEmpty) {
      throw StateError('viewportSize and sensorSize must be non-empty.');
    }
    if (displayedCropRegion.width <= 0 || displayedCropRegion.height <= 0) {
      throw StateError('displayedCropRegion must be non-empty.');
    }

    final displayedSensorSize = transform.orientedSize(sensorSize);
    final cropSize = Size(
      displayedSensorSize.width * displayedCropRegion.width,
      displayedSensorSize.height * displayedCropRegion.height,
    );
    final fitted = applyBoxFit(fit, cropSize, viewportSize);
    final source = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & cropSize,
    );
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & viewportSize,
    );
    final visibleViewportRect = viewportRect.intersect(destination);

    if (visibleViewportRect.isEmpty) {
      throw ArgumentError.value(
        viewportRect,
        'viewportRect',
        'does not intersect the displayed camera preview',
      );
    }

    final scaleX = source.width / destination.width;
    final scaleY = source.height / destination.height;
    final localCropRect = Rect.fromLTRB(
      source.left + (visibleViewportRect.left - destination.left) * scaleX,
      source.top + (visibleViewportRect.top - destination.top) * scaleY,
      source.left + (visibleViewportRect.right - destination.left) * scaleX,
      source.top + (visibleViewportRect.bottom - destination.top) * scaleY,
    ).intersect(Offset.zero & cropSize);

    final local = NormalizedRect.fromRect(localCropRect, cropSize);
    final displayed = NormalizedRect(
      left: displayedCropRegion.left + local.left * displayedCropRegion.width,
      top: displayedCropRegion.top + local.top * displayedCropRegion.height,
      right:
          displayedCropRegion.left + local.right * displayedCropRegion.width,
      bottom:
          displayedCropRegion.top + local.bottom * displayedCropRegion.height,
    );

    return transform.displayedToRaw(displayed);
  }

  /// Maps a viewport rectangle directly to raw sensor pixel coordinates.
  Rect viewportRectToSensorPixels(Rect viewportRect) =>
      viewportRectToSensor(viewportRect).toRect(sensorSize);
}
