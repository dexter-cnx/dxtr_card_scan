import 'dart:async';

import 'package:camera/camera.dart';

import '../geometry/normalized_rect.dart';
import 'card_camera_image_adapter.dart';
import 'card_live_capture_coordinator.dart';
import 'card_live_frame_analyzer.dart';

/// Resolves the visible capture-frame ROI into normalized raw-frame space.
///
/// Returning `null` skips the frame. The resolver owns SC-02 orientation,
/// mirroring, zoom-crop and preview-fit mapping; this session never guesses
/// those platform-specific transforms.
typedef CardLiveFrameRoiResolver = NormalizedRect? Function(CameraImage image);

/// Receives non-fatal live-stream analysis failures.
typedef CardLiveCameraSessionError = void Function(
  Object error,
  StackTrace stackTrace,
);

/// Owns a throttled `CameraController.startImageStream()` analysis session.
///
/// Expensive plane copies are performed only after the interval gate passes.
/// YUV/BGRA conversion, JPEG encoding and Rust analysis then run through
/// [CardLiveFrameAnalyzer] on a worker isolate. At most one frame analysis is
/// in flight, so camera callbacks cannot build an unbounded work queue.
class CardLiveCameraSession {
  CardLiveCameraSession({
    required this.coordinator,
    required this.roiResolver,
    this.analyzer = const CardLiveFrameAnalyzer(),
    this.onError,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CardLiveCaptureCoordinator coordinator;
  final CardLiveFrameAnalyzer analyzer;
  final CardLiveFrameRoiResolver roiResolver;
  final CardLiveCameraSessionError? onError;
  final DateTime Function() _clock;

  final CardCameraImageAdapter _adapter = const CardCameraImageAdapter();

  CameraController? _camera;
  DateTime? _lastAcceptedAt;
  bool _analysisInFlight = false;
  int _generation = 0;

  /// Whether an image stream is currently owned by this session.
  bool get isRunning => _camera != null;

  /// Whether a frame is currently being converted/analyzed.
  bool get analysisInFlight => _analysisInFlight;

  /// Starts consuming frames from [camera].
  ///
  /// Calling this for the already-attached camera is a no-op. A different
  /// running camera must be stopped first.
  Future<void> start(CameraController camera) async {
    if (identical(_camera, camera)) return;
    if (_camera != null) {
      throw StateError('Stop the current live camera session before restarting.');
    }
    if (!camera.value.isInitialized) {
      throw StateError('CameraController must be initialized before start().');
    }

    _camera = camera;
    _lastAcceptedAt = null;
    final generation = ++_generation;
    try {
      await camera.startImageStream((image) => _onImage(image, generation));
    } catch (_) {
      if (identical(_camera, camera)) {
        _camera = null;
      }
      rethrow;
    }
  }

  /// Stops the owned image stream and invalidates in-flight result delivery.
  Future<void> stop() async {
    final camera = _camera;
    if (camera == null) return;

    _camera = null;
    _lastAcceptedAt = null;
    ++_generation;
    coordinator.reset();

    try {
      await camera.stopImageStream();
    } on CameraException catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }

  void _onImage(CameraImage image, int generation) {
    if (generation != _generation || _camera == null || _analysisInFlight) {
      return;
    }

    final now = _clock();
    final previous = _lastAcceptedAt;
    if (previous != null) {
      final elapsed = now.difference(previous);
      if (!elapsed.isNegative && elapsed < coordinator.analysisInterval) {
        return;
      }
    }

    final roi = roiResolver(image);
    if (roi == null) return;

    _lastAcceptedAt = now;
    _analysisInFlight = true;
    try {
      final frame = _adapter.fromCameraImage(image);
      unawaited(_analyze(frame, roi, generation));
    } catch (error, stackTrace) {
      _analysisInFlight = false;
      onError?.call(error, stackTrace);
    }
  }

  Future<void> _analyze(
    CardCameraFrame frame,
    NormalizedRect roi,
    int generation,
  ) async {
    try {
      final sample = await analyzer.analyze(frame, rawFrameRoi: roi);
      if (generation != _generation || _camera == null) return;
      await coordinator.submit(sample);
    } catch (error, stackTrace) {
      if (generation == _generation) {
        onError?.call(error, stackTrace);
      }
    } finally {
      if (generation == _generation) {
        _analysisInFlight = false;
      }
    }
  }
}
