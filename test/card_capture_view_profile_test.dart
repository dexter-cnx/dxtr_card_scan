import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _onCompleted(CardCaptureResult _) async {}

void main() {
  test('legacy CardCaptureView defaults stay unchanged without a profile', () {
    const view = CardCaptureView(onCompleted: _onCompleted);

    expect(view.profile, isNull);
    expect(view.processOptions.autoDetect, isTrue);
    expect(view.processOptions.warpLongEdge, 1600);
    expect(view.processOptions.enhanceForOcr, isFalse);
    expect(view.autoCapture.enabled, isFalse);
  });

  test('profile supplies processing and auto-capture defaults', () {
    const view = CardCaptureView(
      onCompleted: _onCompleted,
      profile: CardCaptureProfile.fast,
    );

    expect(view.profile, CardCaptureProfile.fast);
    expect(view.processOptions, same(CardCaptureProfile.fast.processorOptions));
    expect(view.autoCapture, same(CardCaptureProfile.fast.autoCapture));
  });

  test('explicit options remain authoritative over profile defaults', () {
    const processOptions = CardScanProcessorOptions(
      grayscale: true,
      outputFormat: ProcessorOutputFormat.png,
    );
    const autoCapture = CardAutoCaptureConfig(enabled: true);
    const view = CardCaptureView(
      onCompleted: _onCompleted,
      profile: CardCaptureProfile.ocr,
      processOptions: processOptions,
      autoCapture: autoCapture,
    );

    expect(view.processOptions, same(processOptions));
    expect(view.autoCapture, same(autoCapture));
  });
}
