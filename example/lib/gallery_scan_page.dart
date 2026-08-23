import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';

import 'processed_preview_page.dart';

class GalleryScanPage extends StatelessWidget {
  const GalleryScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CardGalleryCaptureView(
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
        pickAction: 'Pick image',
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
