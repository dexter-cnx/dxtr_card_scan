import 'package:camera/camera.dart';
import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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
      home: ExampleHomePage(cameras: cameras),
    );
  }
}

class ExampleHomePage extends StatelessWidget {
  const ExampleHomePage({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  Future<void> _openGallery(BuildContext context) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !context.mounted) return;
    final result = await Navigator.of(context).push<ImageCropSelection>(
      MaterialPageRoute(
        builder: (_) => GalleryCropPage(imagePath: image.path),
      ),
    );
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Crop: ${result.normalizedRect}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dxtr Card Scan')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EntryCard(
                  icon: Icons.camera_alt_outlined,
                  title: 'Camera',
                  subtitle: 'Capture with frame, flash, torch and pinch zoom.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CameraCapturePage(cameras: cameras),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _EntryCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Gallery',
                  subtitle: 'Pick in the example, then pass its path to crop.',
                  onTap: () => _openGallery(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 42),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class GalleryCropPage extends StatefulWidget {
  const GalleryCropPage({required this.imagePath, super.key});

  final String imagePath;

  @override
  State<GalleryCropPage> createState() => _GalleryCropPageState();
}

class _GalleryCropPageState extends State<GalleryCropPage> {
  late ImageCropSelection _selection = ImageCropSelection(
    imagePath: widget.imagePath,
    normalizedRect: const NormalizedRect(
      left: 0.08,
      top: 0.08,
      right: 0.92,
      bottom: 0.92,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop image')),
      body: ImageCropView(
        imagePath: widget.imagePath,
        initialRect: _selection.normalizedRect,
        onChanged: (selection) => _selection = selection,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_selection),
            icon: const Icon(Icons.check),
            label: const Text('Use crop'),
          ),
        ),
      ),
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
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Camera error: $error')),
      );
    }
    if (camera == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final orientation = MediaQuery.orientationOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CardCaptureView(
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
          _OrientationCameraControls(
            orientation: orientation,
            deviceOrientation: camera.value.deviceOrientation,
            captureController: _captureController,
            flashMode: _flashMode,
            torchEnabled: _torchEnabled,
            zoom: _zoom,
            lastCapture: _lastCapture,
            onBack: () => Navigator.of(context).maybePop(),
            onFlashModeChanged: _setFlashMode,
            onTorchPressed: _toggleTorch,
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

class _OrientationCameraControls extends StatelessWidget {
  const _OrientationCameraControls({
    required this.orientation,
    required this.deviceOrientation,
    required this.captureController,
    required this.flashMode,
    required this.torchEnabled,
    required this.zoom,
    required this.lastCapture,
    required this.onBack,
    required this.onFlashModeChanged,
    required this.onTorchPressed,
  });

  final Orientation orientation;
  final DeviceOrientation deviceOrientation;
  final CardCaptureController captureController;
  final FlashMode flashMode;
  final bool torchEnabled;
  final double zoom;
  final XFile? lastCapture;
  final VoidCallback onBack;
  final ValueChanged<FlashMode> onFlashModeChanged;
  final VoidCallback onTorchPressed;

  @override
  Widget build(BuildContext context) {
    if (orientation == Orientation.portrait) {
      return SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filledTonal(
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 62, top: 8),
                child: _FlashMenu(
                  flashMode: flashMode,
                  onChanged: onFlashModeChanged,
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _ZoomBadge(zoom: zoom),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _TorchButton(
                  enabled: torchEnabled,
                  onPressed: onTorchPressed,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _ShutterButton(captureController: captureController),
              ),
            ),
            if (lastCapture case final capture?)
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 100, 22),
                  child: Text(
                    capture.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final shutterOnRight = deviceOrientation == DeviceOrientation.landscapeLeft;
    final shutterAlignment =
        shutterOnRight ? Alignment.centerRight : Alignment.centerLeft;
    final controlHorizontal = shutterOnRight ? -1.0 : 1.0;
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton.filledTonal(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Align(
            alignment: shutterAlignment,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _ShutterButton(captureController: captureController),
            ),
          ),
          Align(
            alignment: Alignment(controlHorizontal, -1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _FlashMenu(
                flashMode: flashMode,
                onChanged: onFlashModeChanged,
              ),
            ),
          ),
          Align(
            alignment: Alignment(controlHorizontal, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _ZoomBadge(zoom: zoom),
            ),
          ),
          Align(
            alignment: Alignment(controlHorizontal, 1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _TorchButton(
                enabled: torchEnabled,
                onPressed: onTorchPressed,
              ),
            ),
          ),
          if (lastCapture case final capture?)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(100, 0, 100, 8),
                child: Text(
                  capture.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.captureController});

  final CardCaptureController captureController;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.large(
      onPressed: () => captureController.capture(),
      child: const Icon(Icons.camera_alt),
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.zoom});

  final double zoom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text('${zoom.toStringAsFixed(1)}×'),
      ),
    );
  }
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: enabled ? 'Torch off' : 'Torch on',
      onPressed: onPressed,
      icon: Icon(enabled ? Icons.flashlight_on : Icons.flashlight_off),
    );
  }
}

class _FlashMenu extends StatelessWidget {
  const _FlashMenu({required this.flashMode, required this.onChanged});

  final FlashMode flashMode;
  final ValueChanged<FlashMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<FlashMode>(
      tooltip: 'Flash mode',
      initialValue: flashMode,
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: FlashMode.off, child: Text('Flash off')),
        PopupMenuItem(value: FlashMode.auto, child: Text('Flash auto')),
        PopupMenuItem(value: FlashMode.always, child: Text('Flash on')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(_flashIcon(flashMode)),
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
