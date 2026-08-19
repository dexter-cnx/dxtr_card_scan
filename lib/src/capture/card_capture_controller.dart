import 'dart:async';

typedef CardCaptureDelegate = Future<Object?> Function();

/// Coordinates manual capture without owning a camera plugin.
class CardCaptureController {
  CardCaptureDelegate? _delegate;
  bool _disposed = false;

  bool get canCapture => !_disposed && _delegate != null;

  Future<Object?> capture() {
    if (_disposed) {
      throw StateError('CardCaptureController has been disposed.');
    }
    final delegate = _delegate;
    if (delegate == null) {
      throw StateError('No capture delegate is attached.');
    }
    return delegate();
  }

  void attach(CardCaptureDelegate delegate) {
    if (_disposed) {
      throw StateError('CardCaptureController has been disposed.');
    }
    _delegate = delegate;
  }

  void detach(CardCaptureDelegate delegate) {
    if (!_disposed && identical(_delegate, delegate)) {
      _delegate = null;
    }
  }

  /// Releases the attached capture delegate.
  void dispose() {
    _delegate = null;
    _disposed = true;
  }
}
