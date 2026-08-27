import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all built-in profiles keep auto capture disabled', () {
    for (final profile in CardCaptureProfile.values) {
      expect(profile.autoCapture.enabled, isFalse);
    }
  });

  test('ocr profile enables OCR-oriented processing', () {
    final options = CardCaptureProfile.ocr.processorOptions;

    expect(options.autoDetect, isTrue);
    expect(options.enhanceForOcr, isTrue);
    expect(options.outputFormat, ProcessorOutputFormat.jpeg);
  });

  test('fast profile prefers smaller lossy output', () {
    final options = CardCaptureProfile.fast.processorOptions;

    expect(options.warpLongEdge, 1200);
    expect(options.maxDimension, 1400);
    expect(options.jpegQuality, 85);
  });

  test('archival profile uses lossless png output', () {
    final options = CardCaptureProfile.archival.processorOptions;

    expect(options.outputFormat, ProcessorOutputFormat.png);
    expect(options.warpLongEdge, 2400);
  });

  test('manual profile avoids automatic perspective detection', () {
    expect(CardCaptureProfile.manual.processorOptions.autoDetect, isFalse);
  });
}
