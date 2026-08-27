import 'dart:typed_data';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final template = CardTemplate(
    id: 'test-card',
    regions: const [
      CardTemplateRegion(
        name: 'left',
        rect: NormalizedRect(
          left: 0,
          top: 0,
          right: 0.5,
          bottom: 1,
        ),
      ),
      CardTemplateRegion(
        name: 'center',
        rect: NormalizedRect(
          left: 0.25,
          top: 0.25,
          right: 0.75,
          bottom: 0.75,
        ),
      ),
    ],
  );

  Uint8List encodedImage({int width = 10, int height = 8}) {
    final image = img.Image(width: width, height: height);
    return Uint8List.fromList(img.encodePng(image));
  }

  test('extracts regions in template order', () {
    const extractor = CardTemplateExtractor();
    final results = extractor.extractBytes(encodedImage(), template);

    expect(results.map((region) => region.name), ['left', 'center']);
    expect(results[0].width, 5);
    expect(results[0].height, 8);
    expect(results[1].width, 6);
    expect(results[1].height, 4);
    expect(img.decodeImage(results[0].bytes), isNotNull);
    expect(img.decodeImage(results[1].bytes), isNotNull);
  });

  test('quantization uses floor left top and ceil right bottom', () {
    final quantizedTemplate = CardTemplate(
      id: 'quantized',
      regions: const [
        CardTemplateRegion(
          name: 'field',
          rect: NormalizedRect(
            left: 0.11,
            top: 0.11,
            right: 0.61,
            bottom: 0.61,
          ),
        ),
      ],
    );

    const extractor = CardTemplateExtractor();
    final region =
        extractor.extractBytes(encodedImage(), quantizedTemplate).single;

    expect(region.width, 6);
    expect(region.height, 5);
  });

  test('result collection and bytes are detached from caller input', () {
    final bytes = encodedImage();
    const extractor = CardTemplateExtractor();
    final results = extractor.extractBytes(bytes, template);
    final firstByte = results.first.bytes.first;

    bytes.fillRange(0, bytes.length, 0);

    expect(results, isA<List<CardTemplateRegionExtraction>>());
    expect(() => results.add(results.first), throwsUnsupportedError);
    expect(results.first.bytes.first, firstByte);
  });

  test('rejects empty or undecodable corrected image bytes', () {
    const extractor = CardTemplateExtractor();

    expect(
      () => extractor.extractBytes(Uint8List(0), template),
      throwsArgumentError,
    );
    expect(
      () => extractor.extractBytes(Uint8List.fromList([1, 2, 3]), template),
      throwsArgumentError,
    );
  });
}
