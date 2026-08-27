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
      if (!names.add(name)) {
        throw ArgumentError.value(
          region.name,
          'regions',
          'region names must be unique',
        );
      }
      if (region.rect.width <= 0 || region.rect.height <= 0) {
        throw ArgumentError.value(
          region.rect,
          'regions',
          'regions must have non-zero area',
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
