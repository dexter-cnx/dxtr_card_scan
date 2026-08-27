import '../processor/card_scan_processor_options.dart';
import 'card_auto_capture_policy.dart';

/// Named capture presets for common document-capture goals.
///
/// Profiles intentionally keep auto capture disabled. Physical calibration
/// remains the authority for enabling automatic shutter behavior.
enum CardCaptureProfile {
  /// Host-controlled capture without automatic perspective detection.
  manual,

  /// OCR-oriented perspective correction and enhancement.
  ocr,

  /// Lower-cost processing for latency-sensitive capture flows.
  fast,

  /// Higher-fidelity lossless output for long-term retention.
  archival,
}

/// Immutable defaults associated with a [CardCaptureProfile].
extension CardCaptureProfileDefaults on CardCaptureProfile {
  /// Processor options recommended for this profile.
  CardScanProcessorOptions get processorOptions => switch (this) {
        CardCaptureProfile.manual => const CardScanProcessorOptions(),
        CardCaptureProfile.ocr => const CardScanProcessorOptions(
            autoDetect: true,
            warpLongEdge: 1600,
            enhanceForOcr: true,
            maxDimension: 2000,
            outputFormat: ProcessorOutputFormat.jpeg,
            jpegQuality: 92,
          ),
        CardCaptureProfile.fast => const CardScanProcessorOptions(
            autoDetect: true,
            warpLongEdge: 1200,
            maxDimension: 1400,
            outputFormat: ProcessorOutputFormat.jpeg,
            jpegQuality: 85,
          ),
        CardCaptureProfile.archival => const CardScanProcessorOptions(
            autoDetect: true,
            warpLongEdge: 2400,
            outputFormat: ProcessorOutputFormat.png,
          ),
      };

  /// Auto-capture defaults for this profile.
  ///
  /// All built-in profiles remain opt-in for automatic shutter dispatch until
  /// physical calibration evidence supports enabling it safely.
  CardAutoCaptureConfig get autoCapture => const CardAutoCaptureConfig();
}
