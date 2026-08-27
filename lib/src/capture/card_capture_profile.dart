import '../processor/card_scan_processor_options.dart';
import 'card_auto_capture_policy.dart';

/// Named capture presets for common document-capture goals.
///
/// Profiles intentionally keep auto capture disabled. Physical calibration
/// remains the authority for enabling automatic shutter behavior.
enum CardCaptureProfile {
  /// Host-controlled capture without automatic perspective detection.
  manual(
    processorOptions: CardScanProcessorOptions(),
  ),

  /// OCR-oriented perspective correction and enhancement.
  ocr(
    processorOptions: CardScanProcessorOptions(
      autoDetect: true,
      warpLongEdge: 1600,
      enhanceForOcr: true,
      maxDimension: 2000,
      outputFormat: ProcessorOutputFormat.jpeg,
      jpegQuality: 92,
    ),
  ),

  /// Lower-cost processing for latency-sensitive capture flows.
  fast(
    processorOptions: CardScanProcessorOptions(
      autoDetect: true,
      warpLongEdge: 1200,
      maxDimension: 1400,
      outputFormat: ProcessorOutputFormat.jpeg,
      jpegQuality: 85,
    ),
  ),

  /// Higher-fidelity lossless output for long-term retention.
  archival(
    processorOptions: CardScanProcessorOptions(
      autoDetect: true,
      warpLongEdge: 2400,
      outputFormat: ProcessorOutputFormat.png,
    ),
  );

  const CardCaptureProfile({
    required this.processorOptions,
    this.autoCapture = const CardAutoCaptureConfig(),
  });

  /// Processor options recommended for this profile.
  final CardScanProcessorOptions processorOptions;

  /// Auto-capture defaults for this profile.
  ///
  /// All built-in profiles remain opt-in for automatic shutter dispatch until
  /// physical calibration evidence supports enabling it safely.
  final CardAutoCaptureConfig autoCapture;
}
