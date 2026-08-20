import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DxtrCardScanTheme resolves from ThemeData extensions', (
    tester,
  ) async {
    const expected = DxtrCardScanTheme(
      captureFrameStyle: CaptureFrameStyle(
        borderColor: Colors.amber,
        borderWidth: 4,
      ),
      imageCropStyle: ImageCropStyle(
        borderColor: Colors.cyan,
        handleColor: Colors.orange,
      ),
      cameraControlsStyle: CameraControlsStyle(
        shutterSize: 92,
        shutterBackgroundColor: Colors.red,
        activeControlBackgroundColor: Colors.green,
      ),
    );

    late DxtrCardScanTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const <ThemeExtension<dynamic>>[expected],
        ),
        home: Builder(
          builder: (context) {
            resolved = DxtrCardScanTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved.captureFrameStyle.borderColor, Colors.amber);
    expect(resolved.captureFrameStyle.borderWidth, 4);
    expect(resolved.imageCropStyle.borderColor, Colors.cyan);
    expect(resolved.imageCropStyle.handleColor, Colors.orange);
    expect(resolved.cameraControlsStyle.shutterSize, 92);
    expect(resolved.cameraControlsStyle.shutterBackgroundColor, Colors.red);
    expect(
      resolved.cameraControlsStyle.activeControlBackgroundColor,
      Colors.green,
    );
  });

  test('theme interpolation carries Camera, controls and Gallery styles', () {
    const a = DxtrCardScanTheme();
    const b = DxtrCardScanTheme(
      captureFrameStyle: CaptureFrameStyle(borderWidth: 6),
      imageCropStyle: ImageCropStyle(borderWidth: 4, handleSize: 24),
      cameraControlsStyle: CameraControlsStyle(
        shutterSize: 100,
        shutterBorderWidth: 6,
      ),
    );

    final middle = a.lerp(b, 0.5);

    expect(middle.captureFrameStyle.borderWidth, 4);
    expect(middle.imageCropStyle.borderWidth, 3);
    expect(middle.imageCropStyle.handleSize, 20);
    expect(middle.cameraControlsStyle.shutterSize, 90);
    expect(middle.cameraControlsStyle.shutterBorderWidth, 3);
  });
}
