import 'dart:ui';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps cover-fitted viewport rect to full raw sensor', () {
    const mapper = CameraGeometryMapper(
      viewportSize: Size(1000, 1000),
      sensorSize: Size(2000, 1000),
    );

    final mapped = mapper.viewportRectToSensorPixels(
      const Rect.fromLTRB(250, 250, 750, 750),
    );

    expect(mapped, const Rect.fromLTRB(750, 250, 1250, 750));
  });

  test('maps through displayed crop region used by digital zoom', () {
    const mapper = CameraGeometryMapper(
      viewportSize: Size(1000, 1000),
      sensorSize: Size(1000, 1000),
      displayedCropRegion: NormalizedRect(
        left: .25,
        top: .25,
        right: .75,
        bottom: .75,
      ),
    );

    final mapped = mapper.viewportRectToSensor(
      const Rect.fromLTRB(250, 250, 750, 750),
    );

    expect(
      mapped,
      const NormalizedRect(left: .375, top: .375, right: .625, bottom: .625),
    );
  });

  test('maps orientation-normalized preview back to rotated raw sensor', () {
    const mapper = CameraGeometryMapper(
      viewportSize: Size(1000, 500),
      sensorSize: Size(500, 1000),
      transform: CapturedImageTransform(quarterTurnsClockwise: 1),
    );

    final mapped = mapper.viewportRectToSensorPixels(
      const Rect.fromLTRB(100, 100, 400, 400),
    );

    expect(mapped, const Rect.fromLTRB(100, 600, 400, 900));
  });

  test('rejects viewport rect outside a contain-fitted preview', () {
    const mapper = CameraGeometryMapper(
      viewportSize: Size(1000, 1000),
      sensorSize: Size(2000, 1000),
      fit: BoxFit.contain,
    );

    expect(
      () => mapper.viewportRectToSensor(const Rect.fromLTRB(0, 0, 100, 100)),
      throwsArgumentError,
    );
  });
}
