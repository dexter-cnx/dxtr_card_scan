import 'dart:async';

typedef CardCaptureDelegate = Future<Object?> Function();

/// Coordinates manual capture without owning a camera plugin.
class CardCaptureController {
  CardCaptureDelegate? _delegate;

  bool get canCapture => _delegate != null;

  Future<Object?> capture() {
    final delegate = _delegate;
    if (delegate == null) {
      throw StateError('No capture delegate is attached.');
    }
    return delegate();
  }

  void attach(CardCaptureDelegate delegate) => _delegate = delegate;

  void detach(CardCaptureDelegate delegate) {
    if (identical(_delegate, delegate)) {
      _delegate = null;
    }
  }
}
