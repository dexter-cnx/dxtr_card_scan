import 'dart:async';

typedef CardCaptureDelegate = Future<Object?> Function();

/// Coordinates manual capture without owning a camera plugin.
class CardCaptureController {
  CardCaptureDelegate? _delegate;
  bool _enabled = true;
  bool _disposed = false;

  bool get canCapture => !_disposed && _enabled && _delegate != null;

  Future<Object?> capture() {
    if (_disposed) {
      throw StateError('CardCaptureController has been disposed.');
    }
    if (!_enabled) {
      throw StateError('Capture is disabled for the current orientation.');
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

  /// Enables or disables capture without detaching the camera delegate.
  void setCaptureEnabled(bool enabled) {
    if (_disposed) {
      throw StateError('CardCaptureController has been disposed.');
    }
    _enabled = enabled;
  }

  /// Releases the attached capture delegate.
  void dispose() {
    _delegate = null;
    _disposed = true;
  }
}
