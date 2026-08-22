import 'package:dxtr_card_scan/src/crop/image_crop_view.dart';
import 'package:dxtr_card_scan/src/geometry/normalized_rect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('undersized crop at bottom-right expands within normalized bounds', () {
    const input = NormalizedRect(
      left: 0.95,
      top: 0.97,
      right: 1,
      bottom: 1,
    );

    final result = normalizeCropSelection(input);

    expect(result.width, closeTo(0.08, 0.000001));
    expect(result.height, closeTo(0.08, 0.000001));
    expect(result.right, 1);
    expect(result.bottom, 1);
    expect(result.left, closeTo(0.92, 0.000001));
    expect(result.top, closeTo(0.92, 0.000001));
  });

  test('undersized crop away from an edge expands around its center', () {
    const input = NormalizedRect(
      left: 0.48,
      top: 0.48,
      right: 0.52,
      bottom: 0.52,
    );

    final result = normalizeCropSelection(input);

    expect(result.left, closeTo(0.46, 0.000001));
    expect(result.top, closeTo(0.46, 0.000001));
    expect(result.right, closeTo(0.54, 0.000001));
    expect(result.bottom, closeTo(0.54, 0.000001));
  });

  test('already interactive crop geometry remains unchanged', () {
    const input = NormalizedRect(
      left: 0.1,
      top: 0.2,
      right: 0.8,
      bottom: 0.9,
    );

    expect(normalizeCropSelection(input), input);
  });
}
