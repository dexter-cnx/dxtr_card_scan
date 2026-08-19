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
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _error = error);
    }
  }

  Future<Object?> _capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || camera.value.isTakingPicture) {
      return null;
    }
    final file = await camera.takePicture();
    if (mounted) setState(() => _lastCapture = file);
    return file;
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          CardCaptureView(
            controller: _captureController,
            frame: const CaptureFrame.id1(widthFactor: .88),
            previewBuilder: (_) => Center(
              child: AspectRatio(
                aspectRatio: camera.value.aspectRatio,
                child: CameraPreview(camera),
              ),
            ),
            onCapture: _capture,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_lastCapture case final capture?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          capture.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    FloatingActionButton.large(
                      onPressed: () => _captureController.capture(),
                      child: const Icon(Icons.camera_alt),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
