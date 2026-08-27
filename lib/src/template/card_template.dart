import '../geometry/normalized_rect.dart';

/// One named region within a normalized card template.
class CardTemplateRegion {
  const CardTemplateRegion({
    required this.name,
    required this.rect,
  });

  /// Stable region name used by extraction/OCR consumers.
  final String name;

  /// Region bounds relative to the perspective-corrected card image.
  final NormalizedRect rect;
}

/// Describes named normalized regions on a perspective-corrected card.
///
/// Templates are pure Dart metadata. They do not perform image processing and
/// do not depend on camera, UI, or native FFI layers.
class CardTemplate {
  CardTemplate({
    required this.id,
    required List<CardTemplateRegion> regions,
  }) : regions = List.unmodifiable(regions) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }

    final names = <String>{};
    for (final region in regions) {
      final name = region.name.trim();
      if (name.isEmpty) {
        throw ArgumentError.value(
          region.name,
          'regions',
          'region names must not be empty',
        );
      }
      if (name != region.name) {
        throw ArgumentError.value(
          region.name,
          'regions',
          'region names must not contain surrounding whitespace',
        );
      }
      if (!names.add(name)) {
        throw ArgumentError.value(
          region.name,
          'regions',
          'region names must be unique',
        );
      }

      final rect = region.rect;
      if (!rect.left.isFinite ||
          !rect.top.isFinite ||
          !rect.right.isFinite ||
          !rect.bottom.isFinite ||
          rect.left < 0 ||
          rect.top < 0 ||
          rect.right > 1 ||
          rect.bottom > 1 ||
          rect.left >= rect.right ||
          rect.top >= rect.bottom) {
        throw ArgumentError.value(
          rect,
          'regions',
          'region bounds must be finite and satisfy '
              '0 <= left < right <= 1 and 0 <= top < bottom <= 1',
        );
      }
    }
  }

  /// Stable template identifier chosen by the host/application.
  final String id;

  /// Ordered normalized regions in template-defined order.
  final List<CardTemplateRegion> regions;

  /// Returns the region named [name], or `null` when it is not present.
  CardTemplateRegion? region(String name) {
    for (final region in regions) {
      if (region.name == name) return region;
    }
    return null;
  }
}
