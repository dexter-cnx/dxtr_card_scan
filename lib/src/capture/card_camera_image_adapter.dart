import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../geometry/normalized_rect.dart';

/// Raw formats supported by [CardCameraImageAdapter].
enum CardCameraFrameFormat {
  yuv420,
  bgra8888,
}

/// One immutable raw camera plane copied from a plugin frame.
class CardCameraFramePlane {
  const CardCameraFramePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}

/// Camera-plugin-independent raw frame used by live analysis.
class CardCameraFrame {
  const CardCameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
  });

  final int width;
  final int height;
  final CardCameraFrameFormat format;
  final List<CardCameraFramePlane> planes;
}

/// Converts raw camera frames into encoded ROI images accepted by the Rust ABI.
///
/// The adapter deliberately does not rotate or mirror frames. [roi] is in the
/// raw frame coordinate system and must already be mapped by the caller's
/// SC-02 geometry/orientation contract.
class CardCameraImageAdapter {
  const CardCameraImageAdapter();

  /// Copies the camera-plugin frame into an isolate-safe DTO.
  CardCameraFrame fromCameraImage(CameraImage image) {
    final format = switch (image.format.group) {
      ImageFormatGroup.yuv420 => CardCameraFrameFormat.yuv420,
      ImageFormatGroup.bgra8888 => CardCameraFrameFormat.bgra8888,
      _ => throw UnsupportedError(
          'Unsupported camera image format: ${image.format.group}',
        ),
    };

    if (format == CardCameraFrameFormat.yuv420 &&
        image.planes.length != 2 &&
        image.planes.length != 3) {
      throw UnsupportedError(
        'Unsupported YUV420 plane layout: ${image.planes.length} planes',
      );
    }

    return CardCameraFrame(
      width: image.width,
      height: image.height,
      format: format,
      planes: image.planes
          .map(
            (plane) => CardCameraFramePlane(
              bytes: Uint8List.fromList(plane.bytes),
              bytesPerRow: plane.bytesPerRow,
              bytesPerPixel: plane.bytesPerPixel,
            ),
          )
          .toList(growable: false),
    );
  }

  /// Returns the pixel-space width/height ratio of the quantized ROI.
  ///
  /// This uses the same floor/ceil rules as [encodeJpeg], so downstream
  /// geometry can restore the exact analyzed image aspect ratio.
  double roiAspectRatio(CardCameraFrame frame, NormalizedRect roi) {
    if (frame.width <= 0 || frame.height <= 0) {
      throw ArgumentError('frame dimensions must be positive');
    }
    final bounds = _quantizeRoi(frame, roi);
    return bounds.width / bounds.height;
  }

  /// Encodes the requested raw-frame ROI as JPEG for Rust live analysis.
  Uint8List encodeJpeg(
    CardCameraFrame frame, {
    NormalizedRect roi = const NormalizedRect(
      left: 0,
      top: 0,
      right: 1,
      bottom: 1,
    ),
    int quality = 80,
  }) {
    if (frame.width <= 0 || frame.height <= 0) {
      throw ArgumentError('frame dimensions must be positive');
    }
    if (quality < 1 || quality > 100) {
      throw ArgumentError.value(quality, 'quality', 'must be in [1, 100]');
    }

    final bounds = _quantizeRoi(frame, roi);
    final source = switch (frame.format) {
      CardCameraFrameFormat.yuv420 => _decodeYuv420(frame, bounds),
      CardCameraFrameFormat.bgra8888 => _decodeBgra8888(frame, bounds),
    };
    return Uint8List.fromList(img.encodeJpg(source, quality: quality));
  }

  _PixelRoi _quantizeRoi(CardCameraFrame frame, NormalizedRect roi) {
    final left = (roi.left * frame.width)
        .floor()
        .clamp(0, frame.width - 1)
        .toInt();
    final top = (roi.top * frame.height)
        .floor()
        .clamp(0, frame.height - 1)
        .toInt();
    final right = (roi.right * frame.width)
        .ceil()
        .clamp(left + 1, frame.width)
        .toInt();
    final bottom = (roi.bottom * frame.height)
        .ceil()
        .clamp(top + 1, frame.height)
        .toInt();
    return _PixelRoi(left, top, right, bottom);
  }

  img.Image _decodeBgra8888(CardCameraFrame frame, _PixelRoi roi) {
    if (frame.planes.length != 1) {
      throw const FormatException('BGRA8888 requires exactly one plane');
    }
    final plane = frame.planes.single;
    final bytesPerPixel = plane.bytesPerPixel ?? 4;
    if (bytesPerPixel < 4) {
      throw const FormatException('BGRA8888 requires at least 4 bytes per pixel');
    }

    final output = img.Image(width: roi.width, height: roi.height);
    for (var y = roi.top; y < roi.bottom; y += 1) {
      final row = y * plane.bytesPerRow;
      final outY = y - roi.top;
      for (var x = roi.left; x < roi.right; x += 1) {
        final index = row + x * bytesPerPixel;
        if (index + 3 >= plane.bytes.length) {
          throw const FormatException('BGRA8888 plane is shorter than declared');
        }
        output.setPixelRgba(
          x - roi.left,
          outY,
          plane.bytes[index + 2],
          plane.bytes[index + 1],
          plane.bytes[index],
          plane.bytes[index + 3],
        );
      }
    }
    return output;
  }

  img.Image _decodeYuv420(CardCameraFrame frame, _PixelRoi roi) {
    if (frame.planes.length != 2 && frame.planes.length != 3) {
      throw const FormatException('YUV420 requires 2 or 3 planes');
    }
    final yPlane = frame.planes[0];
    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    final output = img.Image(width: roi.width, height: roi.height);

    for (var y = roi.top; y < roi.bottom; y += 1) {
      final uvY = y >> 1;
      final outY = y - roi.top;
      for (var x = roi.left; x < roi.right; x += 1) {
        final uvX = x >> 1;
        final yIndex = y * yPlane.bytesPerRow + x * yPixelStride;
        if (yIndex >= yPlane.bytes.length) {
          throw const FormatException('YUV420 Y plane is shorter than declared');
        }

        final (uValue, vValue) = frame.planes.length == 2
            ? _readBiPlanarUv(frame.planes[1], uvX, uvY)
            : _readTriPlanarUv(frame.planes[1], frame.planes[2], uvX, uvY);

        final yValue = yPlane.bytes[yIndex].toDouble();
        final u = uValue - 128.0;
        final v = vValue - 128.0;
        final r = (yValue + 1.402 * v).round().clamp(0, 255);
        final g = (yValue - 0.344136 * u - 0.714136 * v)
            .round()
            .clamp(0, 255);
        final b = (yValue + 1.772 * u).round().clamp(0, 255);
        output.setPixelRgb(x - roi.left, outY, r, g, b);
      }
    }
    return output;
  }

  (int, int) _readTriPlanarUv(
    CardCameraFramePlane uPlane,
    CardCameraFramePlane vPlane,
    int uvX,
    int uvY,
  ) {
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    final uIndex = uvY * uPlane.bytesPerRow + uvX * uPixelStride;
    final vIndex = uvY * vPlane.bytesPerRow + uvX * vPixelStride;
    if (uIndex >= uPlane.bytes.length || vIndex >= vPlane.bytes.length) {
      throw const FormatException('YUV420 chroma plane is shorter than declared');
    }
    return (uPlane.bytes[uIndex], vPlane.bytes[vIndex]);
  }

  (int, int) _readBiPlanarUv(
    CardCameraFramePlane uvPlane,
    int uvX,
    int uvY,
  ) {
    final pixelStride = uvPlane.bytesPerPixel ?? 2;
    if (pixelStride < 2) {
      throw const FormatException('Bi-planar YUV420 requires UV pixel stride >= 2');
    }
    final index = uvY * uvPlane.bytesPerRow + uvX * pixelStride;
    if (index + 1 >= uvPlane.bytes.length) {
      throw const FormatException('YUV420 UV plane is shorter than declared');
    }
    return (uvPlane.bytes[index], uvPlane.bytes[index + 1]);
  }
}

class _PixelRoi {
  const _PixelRoi(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;
}
