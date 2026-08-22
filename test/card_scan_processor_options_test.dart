import 'dart:convert';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes processor options using Rust field names', () {
    const options = CardScanProcessorOptions(
      quarterTurnsClockwise: 5,
      roi: NormalizedRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8),
      autoDetect: false,
      perspectiveQuad: ProcessorQuad(
        topLeft: ProcessorPoint(0.1, 0.1),
        topRight: ProcessorPoint(0.9, 0.1),
        bottomRight: ProcessorPoint(0.9, 0.9),
        bottomLeft: ProcessorPoint(0.1, 0.9),
      ),
      warpLongEdge: 1600,
      enhanceForOcr: true,
      maxDimension: 1200,
      outputFormat: ProcessorOutputFormat.png,
      jpegQuality: 88,
    );

    final json = jsonDecode(options.toJsonString()) as Map<String, dynamic>;
    expect(json['quarter_turns_clockwise'], 1);
    expect(json['roi'], <String, dynamic>{
      'left': 0.1,
      'top': 0.2,
      'right': 0.9,
      'bottom': 0.8,
    });
    expect(json['auto_detect'], isFalse);
    expect((json['perspective_quad'] as Map<String, dynamic>)['corners'], hasLength(4));
    expect(json['warp_long_edge'], 1600);
    expect(json['enhance_for_ocr'], isTrue);
    expect(json['grayscale'], isFalse);
    expect(json['max_dimension'], 1200);
    expect(json['output_format'], 'png');
    expect(json['jpeg_quality'], 88);
  });

  test('default options remain backwards compatible with Rust defaults', () {
    const options = CardScanProcessorOptions();
    final json = options.toJson();

    expect(json['quarter_turns_clockwise'], 0);
    expect(json['auto_detect'], isFalse);
    expect(json['enhance_for_ocr'], isFalse);
    expect(json['grayscale'], isFalse);
    expect(json['output_format'], 'jpeg');
    expect(json['jpeg_quality'], 92);
    expect(json.containsKey('roi'), isFalse);
    expect(json.containsKey('perspective_quad'), isFalse);
    expect(json.containsKey('warp_long_edge'), isFalse);
    expect(json.containsKey('max_dimension'), isFalse);
  });
}
