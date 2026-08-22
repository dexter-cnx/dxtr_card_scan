import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';

import 'processed_preview_page.dart';

class CameraScanPage extends StatelessWidget {
  const CameraScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CardCaptureView(
        frame: const CaptureFrame.id1(
          widthFactor: .88,
          maxHeightFactor: .82,
        ),
        processOptions: const CardScanProcessorOptions(
          autoDetect: true,
          warpLongEdge: 1600,
          enhanceForOcr: true,
          maxDimension: 1600,
          jpegQuality: 92,
        ),
        confirmationMode: CaptureConfirmationMode.afterCrop,
        labels: const CardCaptureLabels(
          closeTooltip: 'Back',
          confirmTitle: 'Confirm detected card',
          confirmAction: 'Use this scan',
          retakeAction: 'Retake',
        ),
        onClose: () => Navigator.of(context).maybePop(),
        onRawCaptured: (image) async {
          debugPrint('Raw capture: ${image.path}');
        },
        onCropReady: (image) async {
          debugPrint('Rectified crop: ${image.path}');
        },
        onCompleted: (result) async {
          final bytes = await result.processed.readBytes();
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProcessedPreviewPage(
                bytes: bytes,
                title: 'Camera processed output',
              ),
            ),
          );
        },
      ),
    );
  }
}
