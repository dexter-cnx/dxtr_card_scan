import 'dart:typed_data';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const adapter = CardCameraImageAdapter();

  test('encodes BGRA ROI to JPEG with expected dimensions', () {
    final frame = CardCameraFrame(
      width: 4,
      height: 2,
      format: CardCameraFrameFormat.bgra8888,
      planes: [
        CardCameraFramePlane(
          bytes: Uint8List.fromList([
            0, 0, 255, 255,
            0, 255, 0, 255,
            255, 0, 0, 255,
            255, 255, 255, 255,
            0, 0, 255, 255,
            0, 255, 0, 255,
            255, 0, 0, 255,
            255, 255, 255, 255,
          ]),
          bytesPerRow: 16,
          bytesPerPixel: 4,
        ),
      ],
    );

    final encoded = adapter.encodeJpeg(
      frame,
      roi: const NormalizedRect(
        left: .25,
        top: 0,
        right: .75,
        bottom: 1,
      ),
      quality: 100,
    );
    final decoded = img.decodeJpg(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.width, 2);
    expect(decoded.height, 2);
  });

  test('encodes neutral tri-planar YUV420 frame', () {
    final frame = CardCameraFrame(
      width: 2,
      height: 2,
      format: CardCameraFrameFormat.yuv420,
      planes: [
        CardCameraFramePlane(
          bytes: Uint8List.fromList([64, 96, 128, 160]),
          bytesPerRow: 2,
          bytesPerPixel: 1,
        ),
        CardCameraFramePlane(
          bytes: Uint8List.fromList([128]),
          bytesPerRow: 1,
          bytesPerPixel: 1,
        ),
        CardCameraFramePlane(
          bytes: Uint8List.fromList([128]),
          bytesPerRow: 1,
          bytesPerPixel: 1,
        ),
      ],
    );

    final decoded = img.decodeJpg(adapter.encodeJpeg(frame, quality: 100));
    expect(decoded, isNotNull);
    for (final pixel in decoded!) {
      expect((pixel.r - pixel.g).abs(), lessThan(8));
      expect((pixel.g - pixel.b).abs(), lessThan(8));
    }
  });

  test('supports bi-planar YUV420 UV layout', () {
    final frame = CardCameraFrame(
      width: 2,
      height: 2,
      format: CardCameraFrameFormat.yuv420,
      planes: [
        CardCameraFramePlane(
          bytes: Uint8List.fromList([100, 100, 100, 100]),
          bytesPerRow: 2,
          bytesPerPixel: 1,
        ),
        CardCameraFramePlane(
          bytes: Uint8List.fromList([128, 128]),
          bytesPerRow: 2,
          bytesPerPixel: 2,
        ),
      ],
    );

    final decoded = img.decodeJpg(adapter.encodeJpeg(frame, quality: 100));
    expect(decoded, isNotNull);
    expect(decoded!.width, 2);
    expect(decoded.height, 2);
  });

  test('honors Y plane pixel stride', () {
    final frame = CardCameraFrame(
      width: 2,
      height: 1,
      format: CardCameraFrameFormat.yuv420,
      planes: [
        CardCameraFramePlane(
          bytes: Uint8List.fromList([64, 0, 192, 0]),
          bytesPerRow: 4,
          bytesPerPixel: 2,
        ),
        CardCameraFramePlane(
          bytes: Uint8List.fromList([128]),
          bytesPerRow: 1,
          bytesPerPixel: 1,
        ),
        CardCameraFramePlane(
          bytes: Uint8List.fromList([128]),
          bytesPerRow: 1,
          bytesPerPixel: 1,
        ),
      ],
    );

    final decoded = img.decodeJpg(adapter.encodeJpeg(frame, quality: 100));
    expect(decoded, isNotNull);
    expect(decoded!.getPixel(1, 0).r, greaterThan(decoded.getPixel(0, 0).r));
  });

  test('honors YUV row and chroma pixel stride', () {
    final frame = CardCameraFrame(
      width: 2,
      height: 2,
      format: CardCameraFrameFormat.yuv420,
      planes: [
        CardCameraFramePlane(
          bytes: Uint8List.fromList([100, 100, 0, 0, 100, 100, 0, 0]),
          bytesPerRow: 4,
          bytesPerPixel: 1,
        ),
        CardCameraFramePlane(
          bytes: Uint8List.fromList([128, 0]),
          bytesPerRow: 2,
          bytesPerPixel: 2,
        ),
        CardCameraFramePlane(
          bytes: Uint8List.fromList([128, 0]),
          bytesPerRow: 2,
          bytesPerPixel: 2,
        ),
      ],
    );

    final decoded = img.decodeJpg(adapter.encodeJpeg(frame));
    expect(decoded, isNotNull);
    expect(decoded!.width, 2);
    expect(decoded.height, 2);
  });
}
