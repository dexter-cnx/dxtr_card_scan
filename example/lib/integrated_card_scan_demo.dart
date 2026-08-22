import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';

import 'camera_scan_page.dart';
import 'gallery_scan_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = Platform.isMacOS ? <CameraDescription>[] : await availableCameras();
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
                              builder: (_) => CameraScanPage(cameras: cameras),
                            ),
                          ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(Platform.isMacOS ? 'Camera (mobile only)' : 'Camera'),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GalleryScanPage(),
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
