import 'dart:ui';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips between pixel and normalized coordinates', () {
    const size = Size(1000, 500);
    const rect = Rect.fromLTRB(100, 50, 900, 450);
    final normalized = NormalizedRect.fromRect(rect, size);
    expect(normalized, const NormalizedRect(left: .1, top: .1, right: .9, bottom: .9));
    expect(normalized.toRect(size), rect);
  });
}
