import 'dart:ui';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps center viewport rect through a cover-fitted source image', () {
    const geometry = PreviewGeometry(viewportSize: Size(1000, 1000), imageSize: Size(2000, 1000));
    final mapped = geometry.viewportRectToImage(const Rect.fromLTRB(250, 250, 750, 750));
    expect(mapped, const Rect.fromLTRB(750, 250, 1250, 750));
  });
}
