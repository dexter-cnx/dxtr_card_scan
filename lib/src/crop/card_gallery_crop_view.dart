import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../capture/capture_confirmation_mode.dart';
import '../capture/card_capture_image.dart';
import '../capture/card_capture_pipeline.dart';
import '../capture/card_capture_result.dart';
import '../processor/card_scan_processor_options.dart';
import '../ui/card_scan_labels.dart';
import 'image_crop_selection.dart';
import 'image_crop_view.dart';

typedef GalleryCaptureResultCallback = Future<void> Function(
  CardCaptureResult result,
);
typedef GalleryCaptureImageCallback = Future<void> Function(
  CardCaptureImage image,
);

/// High-level Gallery crop + native processing surface.
class CardGalleryCropView extends StatefulWidget {
  const CardGalleryCropView({
    required this.sourcePath,
    required this.onCompleted,
    this.processOptions = const CardScanProcessorOptions(
      autoDetect: true,
      warpLongEdge: 1600,
    ),
    this.initialRect = const NormalizedRect(
      left: .06,
      top: .06,
      right: .94,
      bottom: .94,
    ),
    this.autoDetectInitialCrop = true,
    this.initialCropPadding = .02,
    this.minInitialCropConfidence = .60,
    this.errorDisplayDuration = const Duration(seconds: 5),
    this.confirmationMode = CaptureConfirmationMode.afterCrop,
    this.labels = const GalleryCropLabels(),
    this.onOriginalReady,
    this.onCropReady,
    this.onClose,
    super.key,
  })  : assert(initialCropPadding >= 0 && initialCropPadding < .5),
        assert(minInitialCropConfidence >= 0 && minInitialCropConfidence <= 1);

  final String sourcePath;
  final CardScanProcessorOptions processOptions;
  final NormalizedRect initialRect;

  /// Uses native card detection to seed the editable crop rectangle.
  /// Falls back to [initialRect] when no reliable card is found.
  final bool autoDetectInitialCrop;

  /// Normalized padding added around the detected card bounds.
  final double initialCropPadding;

  /// Minimum detector score required before replacing [initialRect].
  final double minInitialCropConfidence;

  /// How long a processor error remains visible before clearing itself.
  ///
  /// Use [Duration.zero] to keep the error visible until the user dismisses it.
  final Duration errorDisplayDuration;

  final CaptureConfirmationMode confirmationMode;
  final GalleryCropLabels labels;
  final GalleryCaptureImageCallback? onOriginalReady;
  final GalleryCaptureImageCallback? onCropReady;
  final GalleryCaptureResultCallback onCompleted;
  final VoidCallback? onClose;

  @override
  State<CardGalleryCropView> createState() => _CardGalleryCropViewState();
}

class _CardGalleryCropViewState extends State<CardGalleryCropView> {
  final CardCapturePipeline _pipeline = const CardCapturePipeline();

  PreparedCardCapture? _prepared;
  Future<PreparedCardCapture>? _fullPrepareFuture;
  ImageCropSelection? _selection;
  CardCaptureImage? _rectified;
  bool _busy = true;
  bool _selectionTouched = false;
  Object? _error;
  String? _status;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(CardGalleryCropView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourcePath != widget.sourcePath ||
        oldWidget.initialRect != widget.initialRect ||
        oldWidget.autoDetectInitialCrop != widget.autoDetectInitialCrop ||
        oldWidget.initialCropPadding != widget.initialCropPadding ||
        oldWidget.minInitialCropConfidence != widget.minInitialCropConfidence) {
      _prepared = null;
      _fullPrepareFuture = null;
      _selection = null;
      _rectified = null;
      _selectionTouched = false;
      _prepare();
    }
  }

  void _clearError() {
    _errorTimer?.cancel();
    _errorTimer = null;
    if (_error != null && mounted) {
      setState(() => _error = null);
    }
  }

  void _showError(Object error) {
    _errorTimer?.cancel();
    if (!mounted) return;
    setState(() => _error = error);
    if (widget.errorDisplayDuration > Duration.zero) {
      _errorTimer = Timer(widget.errorDisplayDuration, () {
        if (mounted) setState(() => _error = null);
      });
    }
  }

  Future<PreparedCardCapture> _prepareFull(String sourcePath) async {
    final prepared = await _pipeline.prepare(sourcePath);
    if (!mounted || sourcePath != widget.sourcePath) return prepared;
    _prepared = prepared;
    await widget.onOriginalReady?.call(prepared.original);
    return prepared;
  }

  Future<void> _detectInitialCrop(
    String sourcePath,
    CardCaptureImage preview,
  ) async {
    if (!widget.autoDetectInitialCrop) return;

    try {
      final detection = await _pipeline.detect(preview);
      if (!mounted ||
          sourcePath != widget.sourcePath ||
          _selectionTouched ||
          detection == null ||
          detection.confidence < widget.minInitialCropConfidence) {
        return;
      }

      setState(() {
        _selection = ImageCropSelection(
          imagePath: preview.path,
          normalizedRect: detection.boundingRect(
            padding: widget.initialCropPadding,
          ),
        );
      });
    } catch (_) {
      // Initial detection is optional. Keep the already-visible fallback crop
      // when native detection is unavailable or fails.
    }
  }

  Future<void> _prepare() async {
    final sourcePath = widget.sourcePath;
    _errorTimer?.cancel();
    setState(() {
      _busy = true;
      _selectionTouched = false;
      _status = widget.labels.preparing;
      _error = null;
    });

    try {
      final preview = await _pipeline.preparePreview(sourcePath);
      if (!mounted || sourcePath != widget.sourcePath) return;

      // Render the editable crop immediately with the configured fallback.
      // Detection and full-resolution preparation continue in the background.
      setState(() {
        _selection = ImageCropSelection(
          imagePath: preview.path,
          normalizedRect: widget.initialRect,
        );
        _busy = false;
        _status = null;
      });

      final fullPrepare = _prepareFull(sourcePath);
      _fullPrepareFuture = fullPrepare;
      unawaited(fullPrepare.then<void>((_) {}, onError: (_) {}));
      unawaited(_detectInitialCrop(sourcePath, preview));
    } catch (error) {
      if (mounted && sourcePath == widget.sourcePath) {
        _showError(error);
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<PreparedCardCapture> _ensurePrepared() async {
    final prepared = _prepared;
    if (prepared != null) return prepared;

    final pending = _fullPrepareFuture;
    if (pending != null) return pending;

    final sourcePath = widget.sourcePath;
    final future = _prepareFull(sourcePath);
    _fullPrepareFuture = future;
    return future;
  }

  Future<void> _scan() async {
    final selection = _selection;
    if (selection == null || _busy) return;

    _errorTimer?.cancel();
    setState(() {
      _busy = true;
      _status = widget.labels.processing;
      _error = null;
    });
    try {
      final prepared = await _ensurePrepared();
      if (!mounted) return;

      final rectified = await _pipeline.cropAndRectify(
        normalized: prepared.normalized,
        sourceRoi: selection.normalizedRect,
        options: widget.processOptions,
      );
      await widget.onCropReady?.call(rectified);
      if (!mounted) return;

      if (widget.confirmationMode == CaptureConfirmationMode.afterCrop) {
        setState(() => _rectified = rectified);
        return;
      }
      await _finish(rectified, selection.normalizedRect);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _finish(CardCaptureImage rectified, NormalizedRect roi) async {
    final prepared = _prepared;
    if (prepared == null) return;
    _errorTimer?.cancel();
    setState(() {
      _busy = true;
      _status = widget.labels.processing;
      _error = null;
    });
    try {
      final processed = await _pipeline.process(
        cropped: rectified,
        options: widget.processOptions,
      );
      await widget.onCompleted(
        CardCaptureResult(
          original: prepared.original,
          cropped: rectified,
          processed: processed,
          sourceRoi: roi,
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final selection = _selection;
    final rectified = _rectified;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: _busy ? null : widget.onClose,
          tooltip: labels.closeTooltip,
          icon: const Icon(Icons.close),
        ),
        title: Text(rectified == null ? labels.title : labels.confirmTitle),
      ),
      body: Stack(
        children: [
          if (rectified != null)
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: Image.file(File(rectified.path), fit: BoxFit.contain),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _rectified = null),
                            child: Text(labels.retryAction),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy || selection == null
                                ? null
                                : () => _finish(
                                      rectified,
                                      selection.normalizedRect,
                                    ),
                            child: Text(labels.confirmAction),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(labels.instruction, textAlign: TextAlign.center),
                ),
                Expanded(
                  child: selection == null
                      ? const SizedBox.shrink()
                      : ImageCropView(
                          imagePath: selection.imagePath,
                          initialRect: selection.normalizedRect,
                          onChanged: (value) {
                            _selectionTouched = true;
                            _selection = value;
                          },
                        ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${labels.errorPrefix}: $_error',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _clearError,
                          tooltip: labels.dismissErrorTooltip,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selection == null || _busy ? null : _scan,
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: Text(labels.scanAction),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_busy)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: const Color(0x99000000),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_status ?? labels.processing),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
