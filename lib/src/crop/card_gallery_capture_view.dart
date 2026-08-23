import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/capture_confirmation_mode.dart';
import '../processor/card_scan_processor_options.dart';
import '../ui/card_scan_labels.dart';
import 'card_gallery_crop_view.dart';

typedef GalleryImagePathPicker = Future<String?> Function();

/// High-level Gallery source picker + crop + processing surface.
///
/// By default the package uses `image_picker` on Android/iOS and
/// `file_selector` on macOS. Applications can replace only the source-picking
/// step with [pickImagePath] while keeping crop/processing behavior package-
/// owned.
class CardGalleryCaptureView extends StatefulWidget {
  const CardGalleryCaptureView({
    required this.onCompleted,
    this.processOptions = const CardScanProcessorOptions(
      autoDetect: true,
      warpLongEdge: 1600,
    ),
    this.autoDetectInitialCrop = true,
    this.initialCropPadding = .02,
    this.minInitialCropConfidence = .60,
    this.errorDisplayDuration = const Duration(seconds: 5),
    this.confirmationMode = CaptureConfirmationMode.afterCrop,
    this.labels = const GalleryCropLabels(),
    this.pickImagePath,
    this.onOriginalReady,
    this.onCropReady,
    this.onClose,
    super.key,
  })  : assert(initialCropPadding >= 0 && initialCropPadding < .5),
        assert(minInitialCropConfidence >= 0 && minInitialCropConfidence <= 1),
        assert(!errorDisplayDuration.isNegative);

  final CardScanProcessorOptions processOptions;
  final bool autoDetectInitialCrop;
  final double initialCropPadding;
  final double minInitialCropConfidence;
  final Duration errorDisplayDuration;
  final CaptureConfirmationMode confirmationMode;
  final GalleryCropLabels labels;
  final GalleryImagePathPicker? pickImagePath;
  final GalleryCaptureImageCallback? onOriginalReady;
  final GalleryCaptureImageCallback? onCropReady;
  final GalleryCaptureResultCallback onCompleted;
  final VoidCallback? onClose;

  @override
  State<CardGalleryCaptureView> createState() => _CardGalleryCaptureViewState();
}

class _CardGalleryCaptureViewState extends State<CardGalleryCaptureView> {
  String? _sourcePath;
  bool _picking = false;
  Object? _error;

  Future<String?> _defaultPickImagePath() async {
    if (Platform.isMacOS) {
      const imageTypes = XTypeGroup(
        label: 'Images',
        extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
      );
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[imageTypes],
      );
      return file?.path;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      return file?.path;
    }

    throw UnsupportedError(
      'Default Gallery picker currently supports Android, iOS, and macOS.',
    );
  }

  Future<void> _pick() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final path = await (widget.pickImagePath ?? _defaultPickImagePath)();
      if (path != null && mounted) setState(() => _sourcePath = path);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourcePath = _sourcePath;
    if (sourcePath != null) {
      return CardGalleryCropView(
        key: ValueKey(sourcePath),
        sourcePath: sourcePath,
        processOptions: widget.processOptions,
        autoDetectInitialCrop: widget.autoDetectInitialCrop,
        initialCropPadding: widget.initialCropPadding,
        minInitialCropConfidence: widget.minInitialCropConfidence,
        errorDisplayDuration: widget.errorDisplayDuration,
        confirmationMode: widget.confirmationMode,
        labels: widget.labels,
        onOriginalReady: widget.onOriginalReady,
        onCropReady: widget.onCropReady,
        onCompleted: widget.onCompleted,
        onClose: widget.onClose,
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.onClose == null
            ? null
            : IconButton(
                onPressed: _picking ? null : widget.onClose,
                tooltip: widget.labels.closeTooltip,
                icon: const Icon(Icons.close),
              ),
        title: Text(widget.labels.title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.labels.emptyMessage, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _picking ? null : _pick,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(widget.labels.pickAction),
                ),
                if (_picking) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${widget.labels.errorPrefix}: $_error',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
