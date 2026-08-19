import 'dart:ui';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ID-1 frame resolves centered with requested width factor', () {
    const viewport = Size(1000, 800);
    const frame = CaptureFrame.id1(widthFactor: .8);
    final rect = frame.resolve(viewport);
    expect(rect.center, const Offset(500, 400));
    expect(rect.width, 800);
    expect(rect.width / rect.height, closeTo(85.60 / 53.98, 0.0001));
  });
}
