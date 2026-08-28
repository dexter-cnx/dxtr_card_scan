import 'dart:io';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';

class ScanResultPage extends StatelessWidget {
  const ScanResultPage({required this.result, super.key});

  final CardCaptureResult result;

  @override
  Widget build(BuildContext context) {
    final metadata = result.qualityMetadata;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan result')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(File(result.processed.path), fit: BoxFit.contain),
          ),
          const SizedBox(height: 20),
          Text('Processed image', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(result.processed.path),
          const SizedBox(height: 16),
          Text(
            'Source ROI: ${result.sourceRoi.left.toStringAsFixed(3)}, '
            '${result.sourceRoi.top.toStringAsFixed(3)} → '
            '${result.sourceRoi.right.toStringAsFixed(3)}, '
            '${result.sourceRoi.bottom.toStringAsFixed(3)}',
          ),
          const SizedBox(height: 8),
          Text(
            metadata == null
                ? 'Quality metadata: unavailable for this capture path'
                : 'Quality metadata: attached from the latest eligible live sample',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Scan another'),
          ),
        ],
      ),
    );
  }
}
