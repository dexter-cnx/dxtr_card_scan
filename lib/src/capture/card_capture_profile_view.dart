import 'package:camera/camera.dart';

import '../frame/capture_frame.dart';
import '../frame/capture_frame_style.dart';
import '../processor/card_scan_processor_options.dart';
import '../ui/card_scan_labels.dart';
import 'capture_confirmation_mode.dart';
import 'capture_orientation_policy.dart';
import 'card_auto_capture_policy.dart';
import 'card_capture_controller.dart';
import 'card_capture_controls_config.dart';
import 'card_capture_profile.dart';
import 'card_capture_view.dart';

/// Builds [CardCaptureView] instances from named capture profiles without
/// changing the existing const constructor contract of [CardCaptureView].
extension CardCaptureProfileViewFactory on CardCaptureProfile {
  /// Creates a capture view using this profile's defaults.
  ///
  /// Explicit [processOptions] and [autoCapture] values take precedence over
  /// the profile defaults. Built-in profiles keep auto capture disabled unless
  /// the caller explicitly supplies an enabled [CardAutoCaptureConfig].
  CardCaptureView captureView({
    required CardCaptureResultCallback onCompleted,
    CardCaptureController? controller,
    CaptureFrame frame = const CaptureFrame.id1(),
    CaptureFrameStyle? frameStyle,
    CaptureFrameBuilder? frameBuilder,
    CaptureOrientationPolicy orientationPolicy = CaptureOrientationPolicy.any,
    CaptureOrientationMismatchBuilder? orientationMismatchBuilder,
    CardScanProcessorOptions? processOptions,
    CaptureConfirmationMode confirmationMode = CaptureConfirmationMode.none,
    CardCaptureControlsConfig controls = const CardCaptureControlsConfig(),
    CardCaptureControlsBuilder? controlsBuilder,
    CardCaptureLabels labels = const CardCaptureLabels(),
    ResolutionPreset resolutionPreset = ResolutionPreset.max,
    CardAutoCaptureConfig? autoCapture,
    Duration liveAnalysisInterval = const Duration(milliseconds: 180),
    CardLiveStreamTransformResolver? liveStreamTransformResolver,
    CardCaptureImageCallback? onRawCaptured,
    CardCaptureImageCallback? onCropReady,
    void Function()? onClose,
  }) {
    return CardCaptureView(
      controller: controller,
      frame: frame,
      frameStyle: frameStyle,
      frameBuilder: frameBuilder,
      orientationPolicy: orientationPolicy,
      orientationMismatchBuilder: orientationMismatchBuilder,
      processOptions: processOptions ?? processorOptions,
      confirmationMode: confirmationMode,
      controls: controls,
      controlsBuilder: controlsBuilder,
      labels: labels,
      resolutionPreset: resolutionPreset,
      autoCapture: autoCapture ?? this.autoCapture,
      liveAnalysisInterval: liveAnalysisInterval,
      liveStreamTransformResolver: liveStreamTransformResolver,
      onRawCaptured: onRawCaptured,
      onCropReady: onCropReady,
      onCompleted: onCompleted,
      onClose: onClose,
    );
  }
}
