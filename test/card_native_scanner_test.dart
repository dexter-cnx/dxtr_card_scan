import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scan result preserves page order and is immutable', () {
    final result = CardNativeScanResult(
      imagePaths: ['page-1.jpg', 'page-2.jpg'],
    );

    expect(result.imagePaths, ['page-1.jpg', 'page-2.jpg']);
    expect(
      () => result.imagePaths.add('page-3.jpg'),
      throwsUnsupportedError,
    );
  });

  test('scan result rejects an empty successful scan', () {
    expect(
      () => CardNativeScanResult(imagePaths: const []),
      throwsArgumentError,
    );
  });

  test('scanner contract distinguishes unavailable and cancelled states', () async {
    final scanner = _FakeScanner(available: true, result: null);

    expect(await scanner.isAvailable(), isTrue);
    expect(await scanner.scan(), isNull);
  });
}

class _FakeScanner implements CardNativeScanner {
  _FakeScanner({required this.available, required this.result});

  final bool available;
  final CardNativeScanResult? result;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<CardNativeScanResult?> scan() async => result;
}
