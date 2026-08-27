import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _onCompleted(CardCaptureResult _) async {}

void main() {
  test('profile factory applies profile defaults', () {
    final view = CardCaptureProfile.fast.captureView(
      onCompleted: _onCompleted,
    );

    expect(view.processOptions.autoDetect, isTrue);
    expect(view.processOptions.warpLongEdge, 1200);
    expect(view.processOptions.maxDimension, 1400);
    expect(view.processOptions.jpegQuality, 85);
    expect(view.autoCapture.enabled, isFalse);
  });

  test('explicit options override profile defaults', () {
    const processOptions = CardScanProcessorOptions(
      grayscale: true,
      outputFormat: ProcessorOutputFormat.png,
    );
    const autoCapture = CardAutoCaptureConfig(enabled: true);

    final view = CardCaptureProfile.ocr.captureView(
      onCompleted: _onCompleted,
      processOptions: processOptions,
      autoCapture: autoCapture,
    );

    expect(view.processOptions, same(processOptions));
    expect(view.autoCapture, same(autoCapture));
  });

  test('profile factory forwards widget key', () {
    const key = ValueKey<String>('ocr-capture');

    final view = CardCaptureProfile.ocr.captureView(
      key: key,
      onCompleted: _onCompleted,
    );

    expect(view.key, same(key));
  });

  test('legacy const CardCaptureView remains available', () {
    const view = CardCaptureView(onCompleted: _onCompleted);

    expect(view.processOptions.autoDetect, isTrue);
    expect(view.processOptions.warpLongEdge, 1600);
    expect(view.autoCapture.enabled, isFalse);
  });
}
