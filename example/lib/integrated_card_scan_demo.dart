import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(IntegratedCardScanDemo(cameras: cameras));
}

class IntegratedCardScanDemo extends StatelessWidget {
  const IntegratedCardScanDemo({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        extensions: const [CardScanTheme()],
      ),
      home: _HomePage(cameras: cameras),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card Scan Example')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: cameras.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _CameraPage(cameras: cameras),
                            ),
                          ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _GalleryPage(),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraPage extends StatefulWidget {
  const _CameraPage({required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<_CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<_CameraPage> with WidgetsBindingObserver {
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
      final normalized = await _normalizeImage(capture.path);
      final frameRect = _frame.resolve(_viewportSize);
      final roi = PreviewGeometry(
        viewportSize: _viewportSize,
        imageSize: Size(
          normalized.width.toDouble(),
          normalized.height.toDouble(),
        ),
      ).viewportRectToNormalizedImage(frameRect);

      final result = await CardScanProcessor().processFile(
        normalized.path,
        options: CardScanProcessorOptions(
          roi: roi,
          autoDetect: true,
          enhanceForOcr: true,
          warpLongEdge: 1600,
          maxDimension: 1600,
          outputFormat: ProcessorOutputFormat.jpeg,
          jpegQuality: 92,
        ),
      );
      if (!mounted) return capture;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ProcessedPreviewPage(bytes: result),
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
      if (mounted) {
        setState(() {
          _flashMode = mode;
          _torchEnabled = false;
        });
      }
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
                onPressed: onBack,
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
                    onPressed: onTorchPressed,
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

class _GalleryPage extends StatefulWidget {
  const _GalleryPage();

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  ImageCropSelection? _selection;
  bool _busy = false;
  Object? _error;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    try {
      final normalized = await _normalizeImage(picked.path);
      if (!mounted) return;
      setState(() {
        _selection = ImageCropSelection(
          imagePath: normalized.path,
          normalizedRect: const NormalizedRect(
            left: .08,
            top: .08,
            right: .92,
            bottom: .92,
          ),
        );
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error);
    }
  }

  Future<void> _process() async {
    final selection = _selection;
    if (selection == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await CardScanProcessor().processFile(
        selection.imagePath,
        options: CardScanProcessorOptions(
          roi: selection.normalizedRect,
          enhanceForOcr: true,
          maxDimension: 1600,
          outputFormat: ProcessorOutputFormat.jpeg,
          jpegQuality: 92,
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ProcessedPreviewPage(bytes: result),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = _selection;
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery crop')),
      body: Column(
        children: [
          Expanded(
            child: selection == null
                ? const Center(child: Text('Pick an image to begin.'))
                : ImageCropView(
                    imagePath: selection.imagePath,
                    initialRect: selection.normalizedRect,
                    onChanged: (value) => _selection = value,
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Processor error: $_error'),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Pick image'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: selection == null || _busy ? null : _process,
                      icon: const Icon(Icons.tune),
                      label: Text(_busy ? 'Processing…' : 'Process ROI'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessedPreviewPage extends StatelessWidget {
  const _ProcessedPreviewPage({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Processed output')),
      body: ColoredBox(
        color: Colors.black,
        child: Center(
          child: InteractiveViewer(
            minScale: .5,
            maxScale: 6,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _NormalizedImage {
  const _NormalizedImage({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}

Future<_NormalizedImage> _normalizeImage(String path) async {
  final bytes = await File(path).readAsBytes();
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Unable to decode captured image.');
  }
  final normalized = image_lib.bakeOrientation(decoded);
  final outputPath = '$path.normalized.jpg';
  await File(outputPath).writeAsBytes(
    image_lib.encodeJpg(normalized, quality: 96),
    flush: true,
  );
  return _NormalizedImage(
    path: outputPath,
    width: normalized.width,
    height: normalized.height,
  );
}
