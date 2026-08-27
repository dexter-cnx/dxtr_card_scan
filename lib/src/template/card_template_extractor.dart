import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'card_template.dart';

/// One extracted template region encoded as PNG bytes.
class CardTemplateRegionExtraction {
  CardTemplateRegionExtraction({
    required this.name,
    required this.bytes,
    required this.width,
    required this.height,
  }) : bytes = Uint8List.fromList(bytes);

  /// Stable template region name.
  final String name;

  /// PNG-encoded region image bytes.
  final Uint8List bytes;

  /// Extracted pixel width.
  final int width;

  /// Extracted pixel height.
  final int height;
}

/// Extracts named regions from an already perspective-corrected card image.
///
/// This layer performs no card detection or perspective correction. Callers
/// should first run the existing processor pipeline, then pass its corrected
/// encoded output to [extractBytes]. The corrected image is decoded once and
/// regions are cropped in template order.
class CardTemplateExtractor {
  const CardTemplateExtractor();

  /// Extracts every region in [template] from [correctedImageBytes].
  ///
  /// Normalized bounds are quantized conservatively: left/top use floor while
  /// right/bottom use ceil, then all edges are clamped to the decoded image.
  List<CardTemplateRegionExtraction> extractBytes(
    Uint8List correctedImageBytes,
    CardTemplate template,
  ) {
    if (correctedImageBytes.isEmpty) {
      throw ArgumentError('corrected image must not be empty');
    }

    final decoded = img.decodeImage(correctedImageBytes);
    if (decoded == null) {
      throw ArgumentError('corrected image bytes could not be decoded');
    }

    return List.unmodifiable(
      template.regions.map((region) {
        final rect = region.rect;
        final left = (rect.left * decoded.width)
            .floor()
            .clamp(0, decoded.width - 1)
            .toInt();
        final top = (rect.top * decoded.height)
            .floor()
            .clamp(0, decoded.height - 1)
            .toInt();
        final right = (rect.right * decoded.width)
            .ceil()
            .clamp(left + 1, decoded.width)
            .toInt();
        final bottom = (rect.bottom * decoded.height)
            .ceil()
            .clamp(top + 1, decoded.height)
            .toInt();
        final width = right - left;
        final height = bottom - top;
        final cropped = img.copyCrop(
          decoded,
          x: left,
          y: top,
          width: width,
          height: height,
        );

        return CardTemplateRegionExtraction(
          name: region.name,
          bytes: Uint8List.fromList(img.encodePng(cropped)),
          width: width,
          height: height,
        );
      }),
    );
  }
}
