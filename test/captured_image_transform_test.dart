import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps clockwise-rotated preview coordinates back to raw image', () {
    const transform = CapturedImageTransform(quarterTurnsClockwise: 1);
    const displayed = NormalizedRect(
      left: .1,
      top: .2,
      right: .4,
      bottom: .6,
    );

    expect(
      transform.displayedToRaw(displayed),
      const NormalizedRect(left: .2, top: .6, right: .6, bottom: .9),
    );
  });

  test('unmirrors preview before mapping back to raw image', () {
    const transform = CapturedImageTransform(mirrored: true);
    const displayed = NormalizedRect(
      left: .1,
      top: .2,
      right: .4,
      bottom: .6,
    );

    expect(
      transform.displayedToRaw(displayed),
      const NormalizedRect(left: .6, top: .2, right: .9, bottom: .6),
    );
  });
}
