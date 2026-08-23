import 'dart:isolate';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QualityCalibrationPage extends StatefulWidget {
  const QualityCalibrationPage({
    required this.result,
    required this.sourceLabel,
    super.key,
  });

  final CardCaptureResult result;
  final String sourceLabel;

  @override
  State<QualityCalibrationPage> createState() => _QualityCalibrationPageState();
}

class _QualityCalibrationPageState extends State<QualityCalibrationPage> {
  late final Future<_CalibrationSnapshot> _snapshot = _analyze();

  Future<_CalibrationSnapshot> _analyze() async {
    final originalPath = widget.result.original.path;
    final croppedPath = widget.result.cropped.path;
    return Isolate.run(() async {
      final processor = CardScanProcessor();
      final original = await processor.analyzeQualityFile(originalPath);
      final cropped = await processor.analyzeQualityFile(croppedPath);
      return _CalibrationSnapshot(original: original, cropped: cropped);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.sourceLabel} quality calibration')),
      body: FutureBuilder<_CalibrationSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Quality analysis failed: ${snapshot.error}'),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final evidence = data.toEvidence(widget.sourceLabel);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Measurement only — no pass/fail threshold is applied.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _QualityCard(title: 'Original capture', value: data.original),
              const SizedBox(height: 12),
              _QualityCard(title: 'Rectified crop', value: data.cropped),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: evidence));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calibration values copied')),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy calibration values'),
              ),
              const SizedBox(height: 12),
              SelectableText(evidence),
            ],
          );
        },
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.title, required this.value});

  final String title;
  final CardScanQualityAnalysis value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _MetricRow('Blur score', value.blur.score),
            _MetricRow('Laplacian variance', value.blur.laplacianVariance),
            _MetricRow('Exposure score', value.exposure.score),
            _MetricRow('Mean luma', value.exposure.meanLuma),
            _MetricRow('Dark fraction', value.exposure.darkFraction),
            _MetricRow('Bright fraction', value.exposure.brightFraction),
            _MetricRow('Card coverage', value.cardCoverage),
            _MetricRow('Detection confidence', value.detectionConfidence),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SelectableText(value.toStringAsFixed(4)),
        ],
      ),
    );
  }
}

class _CalibrationSnapshot {
  const _CalibrationSnapshot({required this.original, required this.cropped});

  final CardScanQualityAnalysis original;
  final CardScanQualityAnalysis cropped;

  String toEvidence(String source) => '''source: $source
original.blur.score: ${original.blur.score.toStringAsFixed(4)}
original.blur.laplacianVariance: ${original.blur.laplacianVariance.toStringAsFixed(4)}
original.exposure.score: ${original.exposure.score.toStringAsFixed(4)}
original.exposure.meanLuma: ${original.exposure.meanLuma.toStringAsFixed(4)}
original.exposure.darkFraction: ${original.exposure.darkFraction.toStringAsFixed(4)}
original.exposure.brightFraction: ${original.exposure.brightFraction.toStringAsFixed(4)}
original.cardCoverage: ${original.cardCoverage.toStringAsFixed(4)}
original.detectionConfidence: ${original.detectionConfidence.toStringAsFixed(4)}
cropped.blur.score: ${cropped.blur.score.toStringAsFixed(4)}
cropped.blur.laplacianVariance: ${cropped.blur.laplacianVariance.toStringAsFixed(4)}
cropped.exposure.score: ${cropped.exposure.score.toStringAsFixed(4)}
cropped.exposure.meanLuma: ${cropped.exposure.meanLuma.toStringAsFixed(4)}
cropped.exposure.darkFraction: ${cropped.exposure.darkFraction.toStringAsFixed(4)}
cropped.exposure.brightFraction: ${cropped.exposure.brightFraction.toStringAsFixed(4)}
cropped.cardCoverage: ${cropped.cardCoverage.toStringAsFixed(4)}
cropped.detectionConfidence: ${cropped.detectionConfidence.toStringAsFixed(4)}''';
}
