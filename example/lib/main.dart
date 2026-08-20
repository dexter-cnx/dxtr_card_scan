import 'package:camera/camera.dart';
import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(CardScanExample(cameras: cameras));
}

class CardScanExample extends StatelessWidget {
  const CardScanExample({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: CameraCapturePage(cameras: cameras),
    );
  }
}

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  final CardCaptureController _captureController = CardCaptureController();
  CameraController? _camera;
  XFile? _lastCapture;
  Object? _error;

  FlashMode _flashMode = FlashMode.off;
  bool _torchEnabled = false;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _zoomAtScaleStart = 1;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.cameras.isEmpty) {
      setState(() => _error = StateError('No camera is available.'));
      return;
    }

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
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoom = minZoom;
      });
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _error = error);
    }
  }

  Future<Object?> _capture() async {
    final camera = _camera;
    if (camera == null ||
        !camera.value.isInitialized ||
        camera.value.isTakingPicture) {
      return null;
    }
    final file = await camera.takePicture();
    if (mounted) setState(() => _lastCapture = file);
    return file;
  }

  Future<void> _setFlashMode(FlashMode mode) async {
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
      _showCameraError('Flash mode is not supported', error);
    }
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    final enable = !_torchEnabled;
    try {
      await camera.setFlashMode(enable ? FlashMode.torch : _flashMode);
      if (mounted) setState(() => _torchEnabled = enable);
    } on CameraException catch (error) {
      _showCameraError('Torch is not supported', error);
    }
  }

  Future<void> _setZoom(double value) async {
    final camera = _camera;
    if (camera == null) return;
    final clamped = value.clamp(_minZoom, _maxZoom).toDouble();
    try {
      await camera.setZoomLevel(clamped);
      if (mounted) setState(() => _zoom = clamped);
    } on CameraException catch (error) {
      _showCameraError('Zoom is not supported', error);
    }
  }

  void _showCameraError(String message, CameraException error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$message (${error.code})')),
    );
  }

  @override
  void dispose() {
    _camera?.dispose();
    _captureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    if (_error case final error?) {
      return Scaffold(body: Center(child: Text('Camera error: $error')));
    }
    if (camera == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: CardCaptureView(
              controller: _captureController,
              frame: const CaptureFrame.id1(
                widthFactor: .88,
                maxHeightFactor: .82,
              ),
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
              onCapture: _capture,
            ),
          ),
          SafeArea(
            top: false,
            child: _CameraControls(
              captureController: _captureController,
              flashMode: _flashMode,
              torchEnabled: _torchEnabled,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              zoom: _zoom,
              lastCapture: _lastCapture,
              onFlashModeChanged: _setFlashMode,
              onTorchPressed: _toggleTorch,
              onZoomChanged: _setZoom,
            ),
          ),
        ],
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
        final isPortrait = viewport.height >= viewport.width;
        final displayedAspectRatio =
            isPortrait ? 1 / cameraAspectRatio : cameraAspectRatio;

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

class _CameraControls extends StatelessWidget {
  const _CameraControls({
    required this.captureController,
    required this.flashMode,
    required this.torchEnabled,
    required this.minZoom,
    required this.maxZoom,
    required this.zoom,
    required this.lastCapture,
    required this.onFlashModeChanged,
    required this.onTorchPressed,
    required this.onZoomChanged,
  });

  final CardCaptureController captureController;
  final FlashMode flashMode;
  final bool torchEnabled;
  final double minZoom;
  final double maxZoom;
  final double zoom;
  final XFile? lastCapture;
  final ValueChanged<FlashMode> onFlashModeChanged;
  final VoidCallback onTorchPressed;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    final sliderMax = maxZoom > minZoom ? maxZoom : minZoom + 0.01;

    return Material(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: torchEnabled ? 'Torch off' : 'Torch on',
                  onPressed: onTorchPressed,
                  icon: Icon(
                    torchEnabled ? Icons.flashlight_on : Icons.flashlight_off,
                  ),
                ),
                PopupMenuButton<FlashMode>(
                  tooltip: 'Flash mode',
                  initialValue: flashMode,
                  onSelected: onFlashModeChanged,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: FlashMode.off,
                      child: Text('Flash off'),
                    ),
                    PopupMenuItem(
                      value: FlashMode.auto,
                      child: Text('Flash auto'),
                    ),
                    PopupMenuItem(
                      value: FlashMode.always,
                      child: Text('Flash on'),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(_flashIcon(flashMode)),
                  ),
                ),
                Expanded(
                  child: Slider(
                    min: minZoom,
                    max: sliderMax,
                    value: zoom.clamp(minZoom, sliderMax).toDouble(),
                    onChanged: maxZoom > minZoom ? onZoomChanged : null,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text('${zoom.toStringAsFixed(1)}×'),
                ),
              ],
            ),
            Row(
              children: [
                if (lastCapture case final capture?)
                  Expanded(
                    child: Text(
                      capture.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                FloatingActionButton.large(
                  onPressed: () => captureController.capture(),
                  child: const Icon(Icons.camera_alt),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _flashIcon(FlashMode mode) {
    return switch (mode) {
      FlashMode.off => Icons.flash_off,
      FlashMode.auto => Icons.flash_auto,
      FlashMode.always => Icons.flash_on,
      FlashMode.torch => Icons.flashlight_on,
    };
  }
}
