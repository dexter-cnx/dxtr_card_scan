import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'card_capture_controller.dart';

/// Public state/actions exposed to a custom [CardCaptureView] controls builder.
///
/// Camera lifecycle and image processing remain package-owned. A custom
/// controls UI can use this object to trigger capture and manipulate the
/// supported camera controls without owning a [CameraController].
class CardCaptureControlsScope {
  const CardCaptureControlsScope({
    required this.controller,
    required this.flashMode,
    required this.torchEnabled,
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.busy,
    required this.captureEnabled,
    required this.deviceOrientation,
    required this.onFlashModeChanged,
    required this.onTorchPressed,
    required this.onZoomChanged,
    required this.onClose,
  });

  final CardCaptureController controller;
  final FlashMode flashMode;
  final bool torchEnabled;
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final bool busy;
  final bool captureEnabled;
  final DeviceOrientation deviceOrientation;
  final Future<void> Function(FlashMode mode) onFlashModeChanged;
  final Future<void> Function() onTorchPressed;
  final Future<void> Function(double zoom) onZoomChanged;
  final void Function()? onClose;

  bool get canCapture => !busy && captureEnabled && controller.canCapture;
  bool get canClose => !busy && onClose != null;

  Future<Object?> capture() => controller.capture();
  Future<void> setFlashMode(FlashMode mode) => onFlashModeChanged(mode);
  Future<void> toggleTorch() => onTorchPressed();
  Future<void> setZoom(double value) => onZoomChanged(value);
  void close() => onClose?.call();
}
