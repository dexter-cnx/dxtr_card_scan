import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../geometry/normalized_rect.dart';
import '../theme/dxtr_card_scan_theme.dart';
import 'image_crop_selection.dart';
import 'image_crop_style.dart';

/// Lets a user move and resize a crop rectangle over an image file.
///
/// File picking intentionally stays outside this package. The host supplies an
/// [imagePath], while this widget returns only normalized crop geometry.
class ImageCropView extends StatefulWidget {
  /// Creates a manual crop surface for [imagePath].
  const ImageCropView({
    required this.imagePath,
    required this.onChanged,
    this.initialRect = const NormalizedRect(
      left: 0.08,
      top: 0.08,
      right: 0.92,
      bottom: 0.92,
    ),
    this.style,
    super.key,
  });

  /// Image path supplied by the host application.
  final String imagePath;

  /// Initial normalized crop rectangle.
  final NormalizedRect initialRect;

  /// Optional per-widget visual override.
  ///
  /// When null, [DxtrCardScanTheme.imageCropStyle] is used.
  final ImageCropStyle? style;

  /// Called whenever the user moves or resizes the crop rectangle.
  final ValueChanged<ImageCropSelection> onChanged;

  @override
  State<ImageCropView> createState() => _ImageCropViewState();
}

class _ImageCropViewState extends State<ImageCropView> {
  static const double _minimumFraction = 0.08;

  late NormalizedRect _selection;
  ui.Size? _sourceSize;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _selection = widget.initialRect;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(ImageCropView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _selection = widget.initialRect;
      _resolveImage();
    }
  }

  void _resolveImage() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    final provider = FileImage(File(widget.imagePath));
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() {
        _sourceSize = ui.Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  void _emit(NormalizedRect value) {
    setState(() => _selection = value);
    widget.onChanged(
      ImageCropSelection(imagePath: widget.imagePath, normalizedRect: value),
    );
  }

  void _move(DragUpdateDetails details, Rect imageRect) {
    final dx = details.delta.dx / imageRect.width;
    final dy = details.delta.dy / imageRect.height;
    final width = _selection.width;
    final height = _selection.height;
    final left =
        (_selection.left + dx).clamp(0.0, 1.0 - width).toDouble();
    final top =
        (_selection.top + dy).clamp(0.0, 1.0 - height).toDouble();
    _emit(
      NormalizedRect(
        left: left,
        top: top,
        right: left + width,
        bottom: top + height,
      ),
    );
  }

  void _resize(_CropHandle handle, DragUpdateDetails details, Rect imageRect) {
    final dx = details.delta.dx / imageRect.width;
    final dy = details.delta.dy / imageRect.height;
    var left = _selection.left;
    var top = _selection.top;
    var right = _selection.right;
    var bottom = _selection.bottom;

    if (handle.left) {
      left = (left + dx)
          .clamp(0.0, right - _minimumFraction)
          .toDouble();
    } else {
      right = (right + dx)
          .clamp(left + _minimumFraction, 1.0)
          .toDouble();
    }
    if (handle.top) {
      top = (top + dy)
          .clamp(0.0, bottom - _minimumFraction)
          .toDouble();
    } else {
      bottom = (bottom + dy)
          .clamp(top + _minimumFraction, 1.0)
          .toDouble();
    }

    _emit(
      NormalizedRect(left: left, top: top, right: right, bottom: bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceSize = _sourceSize;
    if (sourceSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final style = widget.style ?? DxtrCardScanTheme.of(context).imageCropStyle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final fitted = applyBoxFit(BoxFit.contain, sourceSize, viewport);
        final imageRect = Alignment.center.inscribe(
          fitted.destination,
          Offset.zero & viewport,
        );
        final cropRect =
            _selection.toRect(imageRect.size).shift(imageRect.topLeft);
        final halfHit = style.handleHitSize / 2;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fromRect(
              rect: imageRect,
              child: Image.file(File(widget.imagePath), fit: BoxFit.fill),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _CropOverlayPainter(
                  imageRect: imageRect,
                  cropRect: cropRect,
                  style: style,
                ),
              ),
            ),
            Positioned.fromRect(
              rect: cropRect,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) => _move(details, imageRect),
              ),
            ),
            for (final handle in _CropHandle.values)
              Positioned(
                left: handle.left
                    ? cropRect.left - halfHit
                    : cropRect.right - halfHit,
                top: handle.top
                    ? cropRect.top - halfHit
                    : cropRect.bottom - halfHit,
                width: style.handleHitSize,
                height: style.handleHitSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => _resize(handle, details, imageRect),
                  child: Center(child: _CropHandleDot(style: style)),
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _CropHandle {
  topLeft(true, true),
  topRight(false, true),
  bottomLeft(true, false),
  bottomRight(false, false);

  const _CropHandle(this.left, this.top);

  final bool left;
  final bool top;
}

class _CropHandleDot extends StatelessWidget {
  const _CropHandleDot({required this.style});

  final ImageCropStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: style.handleSize,
      height: style.handleSize,
      decoration: BoxDecoration(
        color: style.handleColor,
        border: Border.all(color: style.handleBorderColor),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.imageRect,
    required this.cropRect,
    required this.style,
  });

  final Rect imageRect;
  final Rect cropRect;
  final ImageCropStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()..addRect(imageRect);
    final inside = Path()..addRect(cropRect);
    final mask = Path.combine(PathOperation.difference, outside, inside);
    canvas.drawPath(mask, Paint()..color = style.overlayColor);
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = style.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.borderWidth,
    );
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) =>
      imageRect != oldDelegate.imageRect ||
      cropRect != oldDelegate.cropRect ||
      style != oldDelegate.style;
}
