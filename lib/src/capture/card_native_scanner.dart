/// Platform-neutral contract for an optional native document scanner.
///
/// Implementations may bridge to platform facilities such as VisionKit or a
/// host-selected Android document scanner without coupling the package core to
/// those SDKs.
abstract interface class CardNativeScanner {
  /// Returns whether this scanner can be used in the current runtime state.
  Future<bool> isAvailable();

  /// Opens the native scanner UI.
  ///
  /// Returns `null` when the user cancels. A successful scan may contain more
  /// than one page; callers decide how those pages enter their capture flow.
  Future<CardNativeScanResult?> scan();
}

/// Images produced by one native scanner session.
class CardNativeScanResult {
  CardNativeScanResult({required List<String> imagePaths})
      : imagePaths = List.unmodifiable(imagePaths) {
    if (imagePaths.isEmpty) {
      throw ArgumentError.value(
        imagePaths,
        'imagePaths',
        'must contain at least one scanned image path',
      );
    }
  }

  /// Scanned image paths in page order.
  final List<String> imagePaths;
}
