import 'package:flutter/material.dart';

import '../frame/capture_frame.dart';
import '../frame/capture_frame_style.dart';
import 'card_capture_controller.dart';

typedef CaptureFrameBuilder = Widget Function(BuildContext context, Rect frameRect);
typedef CardPreviewBuilder = Widget Function(BuildContext context);

/// Camera-agnostic capture surface with a customizable capture frame.
class CardCaptureView extends StatefulWidget {
  const CardCaptureView({
    required this.controller,
    required this.previewBuilder,
    required this.onCapture,
    this.frame = const CaptureFrame.id1(),
    this.frameStyle = const CaptureFrameStyle(),
    this.frameBuilder,
    super.key,
  });

  final CardCaptureController controller;
  final CardPreviewBuilder previewBuilder;
  final CardCaptureDelegate onCapture;
  final CaptureFrame frame;
  final CaptureFrameStyle frameStyle;
  final CaptureFrameBuilder? frameBuilder;

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
    if (oldWidget.controller != widget.controller || oldWidget.onCapture != widget.onCapture) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final frameRect = widget.frame.resolve(size);
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.previewBuilder(context),
            if (widget.frameBuilder case final builder?)
              builder(context, frameRect)
            else
              IgnorePointer(
                child: CustomPaint(
                  painter: _CaptureFramePainter(frameRect, widget.frameStyle),
                ),
              ),
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
    final hole = Path()..addRRect(RRect.fromRectAndRadius(frameRect, Radius.circular(style.cornerRadius)));
    final mask = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(mask, Paint()..color = style.overlayColor);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, Radius.circular(style.cornerRadius)),
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
