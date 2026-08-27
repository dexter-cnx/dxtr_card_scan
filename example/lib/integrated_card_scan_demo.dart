import 'dart:io';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';

import 'camera_scan_page.dart';
import 'gallery_scan_page.dart';
import 'unified_scan_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IntegratedCardScanDemo());
}

class IntegratedCardScanDemo extends StatelessWidget {
  const IntegratedCardScanDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        extensions: const [CardScanTheme()],
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card Scan Example')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '1.0 primary flows',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the unified Camera + Gallery flow for normal app integration. '
                'The standalone examples below show the lower-level primary widgets.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: unifiedCameraAvailable
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const UnifiedScanPage(),
                          ),
                        )
                    : null,
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(
                  unifiedCameraAvailable
                      ? 'Unified Camera + Gallery'
                      : 'Unified Camera + Gallery (mobile only)',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: Platform.isMacOS
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CameraScanPage(),
                          ),
                        ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(
                  Platform.isMacOS ? 'Camera (mobile only)' : 'Camera only',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GalleryScanPage(),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery only'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
