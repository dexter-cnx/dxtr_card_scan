import 'dart:io';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'processed_preview_page.dart';

class GalleryScanPage extends StatefulWidget {
  const GalleryScanPage({super.key});

  @override
  State<GalleryScanPage> createState() => _GalleryScanPageState();
}

class _GalleryScanPageState extends State<GalleryScanPage> {
  String? _sourcePath;

  Future<String?> _pickImagePath() async {
    if (Platform.isMacOS) {
      const imageTypes = XTypeGroup(
        label: 'Images',
        extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
      );
      final picked = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[imageTypes],
      );
      return picked?.path;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    return picked?.path;
  }

  Future<void> _pick() async {
    final path = await _pickImagePath();
    if (path != null && mounted) setState(() => _sourcePath = path);
  }

  @override
  Widget build(BuildContext context) {
    final path = _sourcePath;
    if (path == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gallery example')),
        body: Center(
          child: FilledButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Pick image'),
          ),
        ),
      );
    }

    return CardGalleryCropView(
      sourcePath: path,
      initialRect: const NormalizedRect(
        left: .06,
        top: .06,
        right: .94,
        bottom: .94,
      ),
      processOptions: const CardScanProcessorOptions(
        autoDetect: true,
        warpLongEdge: 1600,
        enhanceForOcr: false,
        maxDimension: 1600,
        jpegQuality: 92,
      ),
      confirmationMode: CaptureConfirmationMode.afterCrop,
      labels: const GalleryCropLabels(
        title: 'Gallery crop',
        scanAction: 'Scan selection',
        confirmAction: 'Use this scan',
        retryAction: 'Adjust crop',
      ),
      onClose: () => Navigator.of(context).maybePop(),
      onCompleted: (result) async {
        final bytes = await result.processed.readBytes();
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProcessedPreviewPage(
              bytes: bytes,
              title: 'Gallery scanned output',
            ),
          ),
        );
      },
    );
  }
}
