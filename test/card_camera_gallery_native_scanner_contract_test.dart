import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScanner implements CardNativeScanner {
  const _FakeScanner();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<CardNativeScanResult?> scan() async => CardNativeScanResult(
        imagePaths: const ['page-1.jpg', 'page-2.jpg'],
      );
}

Future<void> _onCompleted(CardCaptureResult _) async {}

void main() {
  test('unified capture keeps native scanner fallback optional', () {
    const view = CardCameraGalleryCaptureView(
      onCompleted: _onCompleted,
    );

    expect(view.nativeScanner, isNull);
    expect(view.showNativeScannerShortcut, isTrue);
    expect(view.nativeScannerTooltip, 'Scan document');
  });

  test('unified capture retains injected native scanner configuration', () {
    const scanner = _FakeScanner();
    const view = CardCameraGalleryCaptureView(
      onCompleted: _onCompleted,
      nativeScanner: scanner,
      showNativeScannerShortcut: false,
      nativeScannerTooltip: 'Native scan',
    );

    expect(view.nativeScanner, same(scanner));
    expect(view.showNativeScannerShortcut, isFalse);
    expect(view.nativeScannerTooltip, 'Native scan');
  });
}
