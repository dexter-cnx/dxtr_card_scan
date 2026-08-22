import 'dart:ui';

import 'normalized_rect.dart';

/// Describes how an orientation-normalized camera preview relates to the raw
/// captured image.
///
/// [quarterTurnsClockwise] is the clockwise rotation applied to the raw image
/// before it is displayed. [mirrored] means the displayed preview is then
/// mirrored horizontally, as is common for a front camera preview.
class CapturedImageTransform {
  const CapturedImageTransform({
    this.quarterTurnsClockwise = 0,
    this.mirrored = false,
  }) : assert(quarterTurnsClockwise >= 0 && quarterTurnsClockwise <= 3);

  final int quarterTurnsClockwise;
  final bool mirrored;

  /// Size of the image after applying the rotation used by the preview.
  Size orientedSize(Size rawImageSize) => quarterTurnsClockwise.isOdd
      ? Size(rawImageSize.height, rawImageSize.width)
      : rawImageSize;

  /// Maps a rectangle from displayed, normalized preview-image coordinates
  /// back to normalized coordinates in the raw captured image.
  NormalizedRect displayedToRaw(NormalizedRect displayed) {
    final points = <Offset>[
      Offset(displayed.left, displayed.top),
      Offset(displayed.right, displayed.top),
      Offset(displayed.right, displayed.bottom),
      Offset(displayed.left, displayed.bottom),
    ].map(_displayedPointToRaw).toList(growable: false);

    final xs = points.map((point) => point.dx);
    final ys = points.map((point) => point.dy);

    return NormalizedRect(
      left: xs.reduce((a, b) => a < b ? a : b),
      top: ys.reduce((a, b) => a < b ? a : b),
      right: xs.reduce((a, b) => a > b ? a : b),
      bottom: ys.reduce((a, b) => a > b ? a : b),
    );
  }

  Offset _displayedPointToRaw(Offset displayed) {
    final x = mirrored ? 1 - displayed.dx : displayed.dx;
    final y = displayed.dy;

    return switch (quarterTurnsClockwise) {
      0 => Offset(x, y),
      1 => Offset(y, 1 - x),
      2 => Offset(1 - x, 1 - y),
      3 => Offset(1 - y, x),
      _ => throw StateError('quarterTurnsClockwise must be in 0..3'),
    };
  }
}
