import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(NativeProcessorDemo(cameras: cameras));
}

class NativeProcessorDemo extends StatelessWidget {
  const NativeProcessorDemo({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: NativeProcessorHome(cameras: cameras),
    );
  }
}

class NativeProcessorHome extends StatelessWidget {
  const NativeProcessorHome({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Native processor validation')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'This screen validates the Dart FFI -> Rust processor path. No OCR engine is involved.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: cameras.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NativeCameraPage(cameras: cameras),
                      ),
                    ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Camera -> auto detect -> warp'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NativeGalleryPage(),
              ),
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Gallery -> ROI crop'),
          ),
        ],
      ),
    );
  }
}

class NativeCameraPage extends StatefulWidget {
  const NativeCameraPage({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  State<NativeCameraPage> createState() => _NativeCameraPageState();
}

class _NativeCameraPageState extends State<NativeCameraPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _initializing = false;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initialize();
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

  Future<void> _initialize() async {
    if (_initializing || _camera != null || widget.cameras.isEmpty) return;
    _initializing = true;

    final back = widget.cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    final description = back.isEmpty ? widget.cameras.first : back.first;
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _error = null;
      });
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _error = error);
    } finally {
      _initializing = false;
    }
  }

  Future<void> _captureAndProcess() async {
    final camera = _camera;
    if (camera == null || _busy || !camera.value.isInitialized) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final capture = await camera.takePicture();
      final result = await CardScanProcessor().processFile(
        capture.path,
        options: const CardScanProcessorOptions(
          autoDetect: true,
          enhanceForOcr: true,
          warpLongEdge: 1600,
          maxDimension: 1600,
          outputFormat: ProcessorOutputFormat.jpeg,
          jpegQuality: 92,
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProcessedPreviewPage(
            title: 'Camera processed output',
            bytes: result,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(title: const Text('Camera native flow')),
      body: Column(
        children: [
          Expanded(
            child: camera == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : Text('Camera error: $_error'),
                  )
                : CameraPreview(camera),
          ),
          if (_error != null && camera != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Processor error: $_error'),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: camera == null || _busy ? null : _captureAndProcess,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_outlined),
                  label: Text(_busy ? 'Processing…' : 'Capture and process'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NativeGalleryPage extends StatefulWidget {
  const NativeGalleryPage({super.key});

  @override
  State<NativeGalleryPage> createState() => _NativeGalleryPageState();
}

class _NativeGalleryPageState extends State<NativeGalleryPage> {
  ImageCropSelection? _selection;
  File? _normalizedImage;
  bool _busy = false;
  Object? _error;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final normalized = await _normalizeOrientation(picked);
      final previous = _normalizedImage;
      if (!mounted) {
        await normalized.delete().catchError((_) => normalized);
        return;
      }
      setState(() {
        _normalizedImage = normalized;
        _selection = ImageCropSelection(
          imagePath: normalized.path,
          normalizedRect: const NormalizedRect(
            left: 0.08,
            top: 0.08,
            right: 0.92,
            bottom: 0.92,
          ),
        );
      });
      if (previous != null && await previous.exists()) {
        await previous.delete();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _normalizeOrientation(XFile picked) async {
    final sourceBytes = await picked.readAsBytes();
    final decoded = image_lib.decodeImage(sourceBytes);
    if (decoded == null) {
      throw StateError('Could not decode the selected image.');
    }
    final normalized = image_lib.bakeOrientation(decoded);
    final encoded = image_lib.encodeJpg(normalized, quality: 95);
    final directory = await Directory.systemTemp.createTemp('card_scan_gallery_');
    final file = File('${directory.path}/normalized.jpg');
    await file.writeAsBytes(encoded, flush: true);
    return file;
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
          builder: (_) => ProcessedPreviewPage(
            title: 'Gallery processed output',
            bytes: result,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    final normalized = _normalizedImage;
    if (normalized != null) {
      normalized.delete().ignore();
      normalized.parent.delete().ignore();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = _selection;
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery native flow')),
      body: Column(
        children: [
          Expanded(
            child: selection == null
                ? Center(
                    child: _busy
                        ? const CircularProgressIndicator()
                        : const Text('Pick an image to begin.'),
                  )
                : ImageCropView(
                    imagePath: selection.imagePath,
                    initialRect: selection.normalizedRect,
                    onChanged: (value) => _selection = value,
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.tune),
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

class ProcessedPreviewPage extends StatelessWidget {
  const ProcessedPreviewPage({
    required this.title,
    required this.bytes,
    super.key,
  });

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ColoredBox(
        color: Colors.black,
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 6,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
