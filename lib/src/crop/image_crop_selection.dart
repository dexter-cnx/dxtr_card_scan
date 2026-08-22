import '../geometry/normalized_rect.dart';

/// A user-selected crop region for an image file.
class ImageCropSelection {
  /// Creates a crop selection for [imagePath] in normalized image coordinates.
  const ImageCropSelection({
    required this.imagePath,
    required this.normalizedRect,
  });

  /// Source image path supplied by the host application.
  final String imagePath;

  /// Crop rectangle in normalized `[0, 1]` source-image coordinates.
  final NormalizedRect normalizedRect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageCropSelection &&
          imagePath == other.imagePath &&
          normalizedRect == other.normalizedRect;

  @override
  int get hashCode => Object.hash(imagePath, normalizedRect);
}
