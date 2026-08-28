import 'dart:io';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';

import 'scan_result_page.dart';

class UnifiedScanPage extends StatelessWidget {
  const UnifiedScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CardCameraGalleryCaptureView(
        frame: const CaptureFrame.id1(
          widthFactor: .88,
          maxHeightFactor: .82,
        ),
        processOptions: CardCaptureProfile.ocr.processorOptions,
        cameraConfirmationMode: CaptureConfirmationMode.none,
        galleryConfirmationMode: CaptureConfirmationMode.afterCrop,
        labels: const CardCaptureLabels(closeTooltip: 'Back'),
        galleryLabels: const GalleryCropLabels(
          closeTooltip: 'Back',
          pickAction: 'Choose from gallery',
        ),
        showGalleryShortcut: true,
        onClose: () => Navigator.of(context).maybePop(),
        onCompleted: (result) async {
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ScanResultPage(result: result),
            ),
          );
        },
      ),
    );
  }
}

bool get unifiedCameraAvailable => Platform.isAndroid || Platform.isIOS;
