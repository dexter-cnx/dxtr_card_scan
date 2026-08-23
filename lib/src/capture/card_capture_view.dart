import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../frame/capture_frame.dart';
import '../frame/capture_frame_style.dart';
import '../geometry/preview_geometry.dart';
import '../processor/card_scan_processor_options.dart';
import '../theme/card_scan_theme.dart';
import '../ui/card_scan_labels.dart';
import 'capture_confirmation_mode.dart';
import 'capture_orientation_policy.dart';
import 'card_capture_controller.dart';
import 'card_capture_controls_config.dart';
import 'card_capture_controls_scope.dart';
import 'card_capture_image.dart';
import 'card_capture_pipeline.dart';
import 'card_capture_result.dart';

typedef CaptureFrameBuilder = Widget Function(
  BuildContext context,
  Rect frameRect,
);
typedef CaptureOrientationMismatchBuilder = Widget Function(
  BuildContext context,
  Orientation currentOrientation,
  CaptureOrientationPolicy policy,
);
typedef CardCaptureControlsBuilder = Widget Function(
  BuildContext context,
  CardCaptureControlsScope controls,
);
typedef CardCaptureImageCallback = Future<void> Function(
  CardCaptureImage image,
);
typedef CardCaptureResultCallback = Future<void> Function(
  CardCaptureResult result,
);

/// High-level package-owned Camera capture + processing surface.
///
/// The host configures frame geometry, visual style, labels and processing
/// options. Camera lifecycle, controls, capture, EXIF normalization, preview
/// geometry mapping, native rectification and final processing stay inside the
/// package.
class CardCaptureView extends StatefulWidget {
  const CardCaptureView({
    required this.onCompleted,
    this.controller,
    this.frame = const CaptureFrame.id1(),
    this.frameStyle,
    this.frameBuilder,
    this.orientationPolicy = CaptureOrientationPolicy.any,
    this.orientationMismatchBuilder,
    this.processOptions = const CardScanProcessorOptions(
      autoDetect: true,
      warpLongEdge: 1600,
    ),
    this.confirmationMode = CaptureConfirmationMode.none,
    this.controls = const CardCaptureControlsConfig(),
    this.controlsBuilder,
    this.labels = const CardCaptureLabels(),
    this.resolutionPreset = ResolutionPreset.max,
    this.onRawCaptured,
    this.onCropReady,
    this.onClose,
    super.key,
  });

  final CardCaptureController? controller;
  final CaptureFrame frame;
  final CaptureFrameStyle? frameStyle;
  final CaptureFrameBuilder? frameBuilder;
  final CaptureOrientationPolicy orientationPolicy;
  final CaptureOrientationMismatchBuilder? orientationMismatchBuilder;
  final CardScanProcessorOptions processOptions;
  final CaptureConfirmationMode confirmationMode;
  final CardCaptureControlsConfig controls;

  /// Replaces the package's built-in camera controls while keeping camera
  /// lifecycle, capture and processing package-owned.
  ///
  /// When null, [_BuiltInCameraControls] is used.
  final CardCaptureControlsBuilder? controlsBuilder;

  final CardCaptureLabels labels;
  final ResolutionPreset resolutionPreset;
  final CardCaptureImageCallback? onRawCaptured;
  final CardCaptureImageCallback? onCropReady;
  final CardCaptureResultCallback onCompleted;
  final VoidCallback? onClose;

  @override
  State<CardCaptureView> createState() => _CardCaptureViewState();
}

class _CardCaptureViewState extends State<CardCaptureView>
    with WidgetsBindingObserver {
  final CardCapturePipeline _pipeline = const CardCapturePipeline();
  final CardCaptureController _internalController = CardCaptureController();

  CameraController? _camera;
  bool _initializing = false;
  bool _busy = false;
  bool _captureEnabled = true;
  Object? _error;
  Size _viewportSize = Size.zero;
  FlashMode _flashMode = FlashMode.off;
  bool _torchEnabled = false;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _zoomAtScaleStart = 1;
  PreparedCardCapture? _prepared;
  CardCaptureImage? _rectified;
  Rect? _lastFrameRect;
  NormalizedRect? _lastRoi;

  CardCaptureController get _captureController =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _captureController.attach(_capture);
    _initializeCamera();
  }

  @override
  void didUpdateWidget(CardCaptureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController).detach(_capture);
      _captureController.attach(_capture);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    } else {
      _releaseCamera();
    }
  }

  Future<void> _releaseCamera() async {
    final camera = _camera;
    _camera = null;
    if (mounted) setState(() {});
    await camera?.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_initializing || _camera != null) return;
    if (Platform.isMacOS) {
      if (mounted) setState(() => _error = widget.labels.cameraUnavailable);
      return;
    }
    _initializing = true;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError(widget.labels.cameraUnavailable);
      }
      final back = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      final description = back.isEmpty ? cameras.first : back.first;
      controller = CameraController(
        description,
        widget.resolutionPreset,
        enableAudio: false,
      );
      await controller.initialize();
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await controller.dispose();
        controller = null;
        return;
      }
      final readyController = controller;
      setState(() {
        _camera = readyController;
        _error = null;
        _flashMode = FlashMode.off;
        _torchEnabled = false;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoom = minZoom;
      });
      controller = null;
    } catch (error) {
      await controller?.dispose();
      if (mounted) setState(() => _error = error);
    } finally {
      _initializing = false;
    }
  }

  Future<Object?> _capture() async {
    final camera = _camera;
    final frameRect = _lastFrameRect;
    if (camera == null ||
        frameRect == null ||
        _busy ||
        !_captureEnabled ||
        !camera.value.isInitialized ||
        camera.value.isTakingPicture ||
        _viewportSize.isEmpty) {
      return null;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shot = await camera.takePicture();
      final prepared = await _pipeline.prepare(shot.path);
      await widget.onRawCaptured?.call(prepared.original);
      final roi = PreviewGeometry(
        viewportSize: _viewportSize,
        imageSize: Size(
          prepared.normalized.width.toDouble(),
          prepared.normalized.height.toDouble(),
        ),
      ).viewportRectToNormalizedImage(frameRect);
      final rectified = await _pipeline.cropAndRectify(
        normalized: prepared.normalized,
        sourceRoi: roi,
        options: widget.processOptions,
      );
      await widget.onCropReady?.call(rectified);
      if (!mounted) return shot;

      _prepared = prepared;
      _lastRoi = roi;
      if (widget.confirmationMode == CaptureConfirmationMode.afterCrop) {
        setState(() => _rectified = rectified);
      } else {
        await _finish(rectified, roi);
      }
      return shot;
    } catch (error) {
      if (mounted) setState(() => _error = error);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish(CardCaptureImage rectified, NormalizedRect roi) async {
    final prepared = _prepared;
    if (prepared == null) return;
    setState(() => _busy = true);
    try {
      final processed = await _pipeline.process(
        cropped: rectified,
        options: widget.processOptions,
      );
      await widget.onCompleted(
        CardCaptureResult(
          original: prepared.original,
          cropped: rectified,
          processed: processed,
          sourceRoi: roi,
        ),
      );
      if (mounted) setState(() => _rectified = null);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setFlash(FlashMode mode) async {
    final camera = _camera;
    if (camera == null) return;
    try {
      await camera.setFlashMode(mode);
      if (mounted) {
        setState(() {
          _flashMode = mode;
          _torchEnabled = false;
        });
      }
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    final enabled = !_torchEnabled;
    try {
      await camera.setFlashMode(enabled ? FlashMode.torch : _flashMode);
      if (mounted) setState(() => _torchEnabled = enabled);
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _setZoom(double value) async {
    final camera = _camera;
    if (camera == null) return;
    final zoom = value.clamp(_minZoom, _maxZoom).toDouble();
    try {
      await camera.setZoomLevel(zoom);
      if (mounted) setState(() => _zoom = zoom);
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captureController.detach(_capture);
    _internalController.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rectified = _rectified;
    if (rectified != null) {
      return _ConfirmationView(
        image: rectified,
        labels: widget.labels,
        busy: _busy,
        onRetake: () => setState(() => _rectified = null),
        onConfirm: () {
          final roi = _lastRoi;
          if (roi != null) _finish(rectified, roi);
        },
      );
    }

    final camera = _camera;
    if (camera == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Text('${widget.labels.cameraUnavailable}\n$_error'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        final orientation = _viewportSize.height >= _viewportSize.width
            ? Orientation.portrait
            : Orientation.landscape;
        final allowed = widget.orientationPolicy.allows(orientation);
        _captureEnabled = allowed;
        _captureController.setCaptureEnabled(allowed);
        final frameRect = widget.frame.resolve(_viewportSize);
        _lastFrameRect = frameRect;
        final frameStyle =
            widget.frameStyle ?? CardScanTheme.of(context).captureFrameStyle;
        final controlsScope = CardCaptureControlsScope(
          controller: _captureController,
          flashMode: _flashMode,
          torchEnabled: _torchEnabled,
          zoom: _zoom,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
          busy: _busy,
          captureEnabled: allowed,
          deviceOrientation: camera.value.deviceOrientation,
          onFlashModeChanged: _setFlash,
          onTorchPressed: _toggleTorch,
          onZoomChanged: _setZoom,
          onClose: widget.onClose,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (_) => _zoomAtScaleStart = _zoom,
              onScaleUpdate: (details) {
                if (details.pointerCount >= 2) {
                  _setZoom(_zoomAtScaleStart * details.scale);
                }
              },
              child: _CoverCameraPreview(controller: camera),
            ),
            if (allowed)
              if (widget.frameBuilder case final builder?)
                builder(context, frameRect)
              else
                IgnorePointer(
                  child: CustomPaint(
                    painter: _CaptureFramePainter(frameRect, frameStyle),
                  ),
                )
            else if (widget.orientationMismatchBuilder case final builder?)
              builder(context, orientation, widget.orientationPolicy),
            if (widget.controlsBuilder case final builder?)
              builder(context, controlsScope)
            else
              _BuiltInCameraControls(
                camera: camera,
                controller: _captureController,
                config: widget.controls,
                labels: widget.labels,
                flashMode: _flashMode,
                torchEnabled: _torchEnabled,
                zoom: _zoom,
                busy: _busy,
                onClose: widget.onClose,
                onFlashChanged: _setFlash,
                onTorchPressed: _toggleTorch,
              ),
            if (_error != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('$_error'),
                      ),
                    ),
                  ),
                ),
              ),
            if (_busy)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color(0x33000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BuiltInCameraControls extends StatelessWidget {
  const _BuiltInCameraControls({
    required this.camera,
    required this.controller,
    required this.config,
    required this.labels,
    required this.flashMode,
    required this.torchEnabled,
    required this.zoom,
    required this.busy,
    required this.onClose,
    required this.onFlashChanged,
    required this.onTorchPressed,
  });

  final CameraController camera;
  final CardCaptureController controller;
  final CardCaptureControlsConfig config;
  final CardCaptureLabels labels;
  final FlashMode flashMode;
  final bool torchEnabled;
  final double zoom;
  final bool busy;
  final VoidCallback? onClose;
  final ValueChanged<FlashMode> onFlashChanged;
  final VoidCallback onTorchPressed;

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);
    final landscape = orientation == Orientation.landscape;
    final shutterRight =
        camera.value.deviceOrientation == DeviceOrientation.landscapeLeft;
    final shutterAlignment = landscape
        ? Alignment(shutterRight ? 1 : -1, 0)
        : Alignment.bottomCenter;

    return SafeArea(
      child: Stack(
        children: [
          if (config.showBack && onClose != null)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton.filledTonal(
                  onPressed: busy ? null : onClose,
                  tooltip: labels.closeTooltip,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ),
          if (config.showZoom)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Chip(label: Text('${zoom.toStringAsFixed(1)}×')),
              ),
            ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (config.showFlash)
                    PopupMenuButton<FlashMode>(
                      enabled: !busy,
                      initialValue: flashMode,
                      onSelected: onFlashChanged,
                      icon: Icon(_flashIcon(flashMode)),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: FlashMode.off,
                          child: Text(labels.flashOff),
                        ),
                        PopupMenuItem(
                          value: FlashMode.auto,
                          child: Text(labels.flashAuto),
                        ),
                        PopupMenuItem(
                          value: FlashMode.always,
                          child: Text(labels.flashOn),
                        ),
                      ],
                    ),
                  if (config.showTorch)
                    IconButton(
                      onPressed: busy ? null : onTorchPressed,
                      tooltip: labels.torchTooltip,
                      icon: Icon(
                        torchEnabled
                            ? Icons.flashlight_on
                            : Icons.flashlight_off,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (config.showShutter)
            Align(
              alignment: shutterAlignment,
              child: Padding(
                padding: EdgeInsets.only(
                  left: landscape && !shutterRight ? 18 : 0,
                  right: landscape && shutterRight ? 18 : 0,
                  bottom: landscape ? 0 : 24,
                ),
                child: SizedBox.square(
                  dimension: CardScanTheme.of(context)
                      .cameraControlsStyle
                      .shutterSize,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: CardScanTheme.of(context)
                          .cameraControlsStyle
                          .shutterShape,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: busy ? null : () => controller.capture(),
                    child: const Icon(Icons.camera_alt, size: 32),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _flashIcon(FlashMode mode) => switch (mode) {
        FlashMode.off => Icons.flash_off,
        FlashMode.auto => Icons.flash_auto,
        FlashMode.always => Icons.flash_on,
        FlashMode.torch => Icons.flashlight_on,
      };
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({
    required this.image,
    required this.labels,
    required this.busy,
    required this.onRetake,
    required this.onConfirm,
  });

  final CardCaptureImage image;
  final CardCaptureLabels labels;
  final bool busy;
  final VoidCallback onRetake;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(labels.confirmTitle),
        ),
        Expanded(
          child: Center(
            child: Image.file(File(image.path), fit: BoxFit.contain),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onRetake,
                    child: Text(labels.retakeAction),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onConfirm,
                    child: Text(labels.confirmAction),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final cameraAspectRatio = controller.value.aspectRatio;
        final portrait = viewport.height >= viewport.width;
        final displayedAspectRatio =
            portrait ? 1 / cameraAspectRatio : cameraAspectRatio;
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: displayedAspectRatio * 1000,
              height: 1000,
              child: CameraPreview(controller),
            ),
          ),
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
