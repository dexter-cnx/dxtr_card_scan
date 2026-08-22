import 'package:camera/camera.dart';
import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'background_scan_tasks.dart';
import 'processed_preview_page.dart';

class CameraScanPage extends StatefulWidget {
  const CameraScanPage({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  State<CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage>
    with WidgetsBindingObserver {
  static const _frame = CaptureFrame.id1(
    widthFactor: .88,
    maxHeightFactor: .82,
  );

  final CardCaptureController _captureController = CardCaptureController();
  CameraController? _camera;
  Size _viewportSize = Size.zero;
  Object? _error;
  bool _initializing = false;
  bool _busy = false;
  FlashMode _flashMode = FlashMode.off;
  bool _torchEnabled = false;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _zoomAtScaleStart = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
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
    if (_initializing || _camera != null || widget.cameras.isEmpty) return;
    _initializing = true;
    final back = widget.cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    final description = back.isEmpty ? widget.cameras.first : back.first;
    final controller = CameraController(
      description,
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _error = null;
        _flashMode = FlashMode.off;
        _torchEnabled = false;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoom = minZoom;
      });
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _error = error);
    } finally {
      _initializing = false;
    }
  }

  Future<Object?> _captureAndProcess() async {
    final camera = _camera;
    if (camera == null ||
        _busy ||
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
      final capture = await camera.takePicture();
      final prepared = await prepareImageInBackground(capture.path);
      final frameRect = _frame.resolve(_viewportSize);
      final roi = PreviewGeometry(
        viewportSize: _viewportSize,
        imageSize: Size(
          prepared.width.toDouble(),
          prepared.height.toDouble(),
        ),
      ).viewportRectToNormalizedImage(frameRect);

      final result = await processScanInBackground(
        imagePath: prepared.path,
        roi: roi,
        autoDetect: true,
        enhanceForOcr: true,
        warpLongEdge: 1600,
      );
      if (!mounted) return capture;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProcessedPreviewPage(
            bytes: result,
            title: 'Camera processed output',
          ),
        ),
      );
      return capture;
    } catch (error) {
      if (mounted) setState(() => _error = error);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setFlash(FlashMode mode) async {
    final camera = _camera;
    if (camera == null) return;
    try {
      await camera.setFlashMode(mode);
      if (!mounted) return;
      setState(() {
        _flashMode = mode;
        _torchEnabled = false;
      });
    } on CameraException catch (error) {
      _showError('Flash is not supported (${error.code})');
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
      _showError('Torch is not supported (${error.code})');
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
      _showError('Zoom is not supported (${error.code})');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _captureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    if (camera == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Text('Camera error: $_error'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = constraints.biggest;
          return Stack(
            fit: StackFit.expand,
            children: [
              CardCaptureView(
                controller: _captureController,
                frame: _frame,
                previewBuilder: (_) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (_) => _zoomAtScaleStart = _zoom,
                  onScaleUpdate: (details) {
                    if (details.pointerCount >= 2) {
                      _setZoom(_zoomAtScaleStart * details.scale);
                    }
                  },
                  child: _CoverCameraPreview(controller: camera),
                ),
                onCapture: _captureAndProcess,
              ),
              _CameraControls(
                orientation: MediaQuery.orientationOf(context),
                deviceOrientation: camera.value.deviceOrientation,
                captureController: _captureController,
                flashMode: _flashMode,
                torchEnabled: _torchEnabled,
                zoom: _zoom,
                busy: _busy,
                onBack: () => Navigator.of(context).maybePop(),
                onFlashChanged: _setFlash,
                onTorchPressed: _toggleTorch,
              ),
              if (_error != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      child: Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Processor error: $_error'),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_busy)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Color(0x22000000),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CameraControls extends StatelessWidget {
  const _CameraControls({
    required this.orientation,
    required this.deviceOrientation,
    required this.captureController,
    required this.flashMode,
    required this.torchEnabled,
    required this.zoom,
    required this.busy,
    required this.onBack,
    required this.onFlashChanged,
    required this.onTorchPressed,
  });

  final Orientation orientation;
  final DeviceOrientation deviceOrientation;
  final CardCaptureController captureController;
  final FlashMode flashMode;
  final bool torchEnabled;
  final double zoom;
  final bool busy;
  final VoidCallback onBack;
  final ValueChanged<FlashMode> onFlashChanged;
  final VoidCallback onTorchPressed;

  @override
  Widget build(BuildContext context) {
    final landscape = orientation == Orientation.landscape;
    final shutterRight = deviceOrientation == DeviceOrientation.landscapeLeft;
    final shutterAlignment = landscape
        ? Alignment(shutterRight ? 1 : -1, 0)
        : Alignment.bottomCenter;

    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton.filledTonal(
                onPressed: busy ? null : onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
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
                  PopupMenuButton<FlashMode>(
                    enabled: !busy,
                    initialValue: flashMode,
                    onSelected: onFlashChanged,
                    icon: Icon(_flashIcon(flashMode)),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: FlashMode.off, child: Text('Flash off')),
                      PopupMenuItem(value: FlashMode.auto, child: Text('Flash auto')),
                      PopupMenuItem(value: FlashMode.always, child: Text('Flash on')),
                    ],
                  ),
                  IconButton(
                    onPressed: busy ? null : onTorchPressed,
                    icon: Icon(
                      torchEnabled ? Icons.flashlight_on : Icons.flashlight_off,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: shutterAlignment,
            child: Padding(
              padding: EdgeInsets.only(
                left: landscape && !shutterRight ? 18 : 0,
                right: landscape && shutterRight ? 18 : 0,
                bottom: landscape ? 0 : 24,
              ),
              child: _ShutterButton(
                busy: busy,
                onPressed: busy ? null : captureController.capture,
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

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onPressed});

  final bool busy;
  final Future<Object?> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 76,
      child: FilledButton(
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed == null ? null : () => onPressed!(),
        child: busy
            ? const SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : const Icon(Icons.camera_alt, size: 32),
      ),
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
