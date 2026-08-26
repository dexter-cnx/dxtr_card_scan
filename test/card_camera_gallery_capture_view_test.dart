import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unified capture defaults keep gallery shortcut enabled', () {
    final view = CardCameraGalleryCaptureView(
      onCompleted: (_) async {},
    );

    expect(view.showGalleryShortcut, isTrue);
    expect(view.cameraConfirmationMode, CaptureConfirmationMode.none);
    expect(
      view.galleryConfirmationMode,
      CaptureConfirmationMode.afterCrop,
    );
  });

  test('host can override gallery picker', () async {
    var called = false;
    final view = CardCameraGalleryCaptureView(
      pickGalleryImagePath: () async {
        called = true;
        return '/tmp/card.jpg';
      },
      onCompleted: (_) async {},
    );

    final path = await view.pickGalleryImagePath?.call();

    expect(called, isTrue);
    expect(path, '/tmp/card.jpg');
  });
}
