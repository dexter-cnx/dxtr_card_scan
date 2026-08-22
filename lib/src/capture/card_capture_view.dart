import 'package:flutter/material.dart';

import '../frame/capture_frame.dart';
import '../frame/capture_frame_style.dart';
import '../theme/card_scan_theme.dart';
import 'capture_orientation_policy.dart';
import 'card_capture_controller.dart';

typedef CaptureFrameBuilder = Widget Function(BuildContext context, Rect frameRect);
typedef CardPreviewBuilder = Widget Function(BuildContext context);
typedef CaptureOrientationMismatchBuilder = Widget Function(
  BuildContext context,
  Orientation currentOrientation,
  CaptureOrientationPolicy policy,
);

/// Camera-agnostic capture surface with a customizable capture frame.
class CardCaptureView extends StatefulWidget {
  const CardCaptureView({
    required this.controller,
    required this.previewBuilder,
    required this.onCapture,
    this.frame = const CaptureFrame.id1(),
    this.frameStyle,
    this.frameBuilder,
    this.orientationPolicy = CaptureOrientationPolicy.any,
    this.orientationMismatchBuilder,
    super.key,
  });

  final CardCaptureController controller;
  final CardPreviewBuilder previewBuilder;
  final CardCaptureDelegate onCapture;
  final CaptureFrame frame;

  /// Optional per-widget visual override.
  ///
  /// When null, [CardScanTheme.captureFrameStyle] is used.
  final CaptureFrameStyle? frameStyle;

  final CaptureFrameBuilder? frameBuilder;

  /// Which viewport orientations are allowed to capture.
  ///
  /// This does not lock the host application's OS orientation. It controls
  /// only this capture surface: when the current orientation is not allowed,
  /// the frame is hidden and [controller] cannot capture.
  final CaptureOrientationPolicy orientationPolicy;

  /// Optional UI shown over the preview when [orientationPolicy] rejects the
  /// current viewport orientation.
  final CaptureOrientationMismatchBuilder? orientationMismatchBuilder;

  @override
  State<CardCaptureView> createState() => _CardCaptureViewState();
}

class _CardCaptureViewState extends State<CardCaptureView> {
  @override
  void initState() {
    super.initState();
    widget.controller.attach(widget.onCapture);
  }

  @override
  void didUpdateWidget(CardCaptureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.onCapture != widget.onCapture) {
      oldWidget.controller.detach(oldWidget.onCapture);
      widget.controller.attach(widget.onCapture);
    }
  }

  @override
  void dispose() {
    widget.controller.detach(widget.onCapture);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themedStyle = CardScanTheme.of(context).captureFrameStyle;
    final frameStyle = widget.frameStyle ?? themedStyle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final orientation = size.height >= size.width
            ? Orientation.portrait
            : Orientation.landscape;
        final orientationAllowed = widget.orientationPolicy.allows(orientation);
        widget.controller.setCaptureEnabled(orientationAllowed);

        final frameRect = widget.frame.resolve(size);
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.previewBuilder(context),
            if (orientationAllowed)
              if (widget.frameBuilder case final builder?)
                builder(context, frameRect)
              else
                IgnorePointer(
                  child: CustomPaint(
                    painter: _CaptureFramePainter(frameRect, frameStyle),
                  ),
                )
            else if (widget.orientationMismatchBuilder
                case final mismatchBuilder?)
              mismatchBuilder(context, orientation, widget.orientationPolicy),
          ],
        );
      },
    );
  }
}

class _CaptureFramePainter extends CustomPainter {
  const _CaptureFramePainter(this.frameRect, this.style);

  final Rect frameRect;
  final CaptureFrameStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          frameRect,
          Radius.circular(style.cornerRadius),
        ),
      );
    final mask = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(mask, Paint()..color = style.overlayColor);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        frameRect,
        Radius.circular(style.cornerRadius),
      ),
      Paint()
        ..color = style.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.borderWidth,
    );
  }

  @override
  bool shouldRepaint(_CaptureFramePainter oldDelegate) =>
      frameRect != oldDelegate.frameRect || style != oldDelegate.style;
}
