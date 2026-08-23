import 'dart:convert';

import '../geometry/normalized_rect.dart';

/// Normalized point in post-orientation, post-ROI image coordinates.
class ProcessorPoint {
  const ProcessorPoint(this.x, this.y)
      : assert(x >= 0 && x <= 1),
        assert(y >= 0 && y <= 1);

  final double x;
  final double y;

  Map<String, Object> toJson() => <String, Object>{'x': x, 'y': y};
}

/// Clockwise quadrilateral in normalized post-orientation, post-ROI coordinates.
class ProcessorQuad {
  const ProcessorQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final ProcessorPoint topLeft;
  final ProcessorPoint topRight;
  final ProcessorPoint bottomRight;
  final ProcessorPoint bottomLeft;

  Map<String, Object> toJson() => <String, Object>{
        'corners': <Map<String, Object>>[
          topLeft.toJson(),
          topRight.toJson(),
          bottomRight.toJson(),
          bottomLeft.toJson(),
        ],
      };
}

enum ProcessorOutputFormat { jpeg, png }

/// Immutable options for the Rust-backed image processor.
class CardScanProcessorOptions {
  const CardScanProcessorOptions({
    this.quarterTurnsClockwise = 0,
    this.roi,
    this.autoDetect = false,
    this.perspectiveQuad,
    this.warpLongEdge,
    this.enhanceForOcr = false,
    this.grayscale = false,
    this.maxDimension,
    this.outputFormat = ProcessorOutputFormat.jpeg,
    this.jpegQuality = 92,
  })  : assert(quarterTurnsClockwise >= 0),
        assert(warpLongEdge == null ||
            (warpLongEdge >= 2 && warpLongEdge <= 4096)),
        assert(maxDimension == null || maxDimension > 0),
        assert(jpegQuality >= 1 && jpegQuality <= 100),
        assert(!autoDetect || perspectiveQuad == null);

  final int quarterTurnsClockwise;
  final NormalizedRect? roi;
  final bool autoDetect;
  final ProcessorQuad? perspectiveQuad;
  final int? warpLongEdge;
  final bool enhanceForOcr;
  final bool grayscale;
  final int? maxDimension;
  final ProcessorOutputFormat outputFormat;
  final int jpegQuality;

  Map<String, Object?> toJson() => <String, Object?>{
        'quarter_turns_clockwise': quarterTurnsClockwise % 4,
        if (roi case final value?)
          'roi': <String, double>{
            'left': value.left,
            'top': value.top,
            'right': value.right,
            'bottom': value.bottom,
          },
        'auto_detect': autoDetect,
        if (perspectiveQuad case final value?)
          'perspective_quad': value.toJson(),
        if (warpLongEdge case final value?) 'warp_long_edge': value,
        'enhance_for_ocr': enhanceForOcr,
        'grayscale': grayscale,
        if (maxDimension case final value?) 'max_dimension': value,
        'output_format': outputFormat.name,
        'jpeg_quality': jpegQuality,
      };

  String toJsonString() => jsonEncode(toJson());
}
