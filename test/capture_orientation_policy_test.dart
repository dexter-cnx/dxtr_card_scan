import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('any allows both orientations', () {
    expect(CaptureOrientationPolicy.any.allows(Orientation.portrait), isTrue);
    expect(CaptureOrientationPolicy.any.allows(Orientation.landscape), isTrue);
  });

  test('portraitOnly rejects landscape', () {
    expect(
      CaptureOrientationPolicy.portraitOnly.allows(Orientation.portrait),
      isTrue,
    );
    expect(
      CaptureOrientationPolicy.portraitOnly.allows(Orientation.landscape),
      isFalse,
    );
  });

  test('landscapeOnly rejects portrait', () {
    expect(
      CaptureOrientationPolicy.landscapeOnly.allows(Orientation.landscape),
      isTrue,
    );
    expect(
      CaptureOrientationPolicy.landscapeOnly.allows(Orientation.portrait),
      isFalse,
    );
  });
}
