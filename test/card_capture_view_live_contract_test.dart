import 'package:camera/camera.dart';
import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CardCaptureView keeps live streaming opt-in', () {
    final view = CardCaptureView(
      onCompleted: (_) async {},
    );

    expect(view.liveStreamTransformResolver, isNull);
    expect(view.autoCapture.enabled, isFalse);
    expect(view.liveAnalysisInterval, const Duration(milliseconds: 180));
  });

  test('live transform resolver can decline unvalidated orientations', () {
    final camera = CameraDescription(
      name: 'test',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );
    final CardLiveStreamTransformResolver resolver = (_, orientation) {
      if (orientation != DeviceOrientation.portraitUp) return null;
      return const CapturedImageTransform(quarterTurnsClockwise: 1);
    };

    expect(resolver(camera, DeviceOrientation.landscapeLeft), isNull);
    expect(
      resolver(camera, DeviceOrientation.portraitUp)?.quarterTurnsClockwise,
      1,
    );
  });
}
