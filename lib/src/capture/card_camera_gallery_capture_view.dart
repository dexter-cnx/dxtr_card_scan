import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../crop/card_gallery_capture_view.dart';
import '../crop/card_gallery_crop_view.dart';
import '../frame/capture_frame.dart';
import '../frame/capture_frame_style.dart';
import '../processor/card_scan_processor_options.dart';
import '../ui/card_scan_labels.dart';
import 'capture_confirmation_mode.dart';
import 'capture_orientation_policy.dart';
import 'card_capture_controller.dart';
import 'card_capture_controls_config.dart';
import 'card_capture_image.dart';
import 'card_capture_result.dart';
import 'card_capture_view.dart';

/// Unified capture surface that lets users switch from Camera to Gallery
/// without leaving the scan flow.
///
/// The Gallery shortcut is package-owned, but applications can replace the
/// source picker through [pickGalleryImagePath]. The selected file continues
/// through the package-owned Gallery crop and native processing pipeline.
class CardCameraGalleryCaptureView extends StatefulWidget {
  const CardCameraGalleryCaptureView({
    required this.onCompleted,
    this.controller,
    this.frame = const CaptureFrame.id1(),
    this.frameStyle,
    this.frameBuilder,
    this.orientationPolicy = CaptureOrientationPolicy.any,
    this.orientationMismatchBuilder,
    this.processOptions = const CardScanProcessorOptions(
      autoDetect: true,
      warpLongEdge: 1600,
    ),
    this.cameraConfirmationMode = CaptureConfirmationMode.none,
    this.galleryConfirmationMode = CaptureConfirmationMode.afterCrop,
    this.controls = const CardCaptureControlsConfig(),
    this.controlsBuilder,
    this.labels = const CardCaptureLabels(),
    this.galleryLabels = const GalleryCropLabels(),
    this.resolutionPreset = ResolutionPreset.max,
    this.pickGalleryImagePath,
    this.showGalleryShortcut = true,
    this.onRawCaptured,
    this.onCropReady,
    this.onClose,
    super.key,
  });

  final CardCaptureController? controller;
  final CaptureFrame frame;
  final CaptureFrameStyle? frameStyle;
  final CaptureFrameBuilder? frameBuilder;
  final CaptureOrientationPolicy orientationPolicy;
  final CaptureOrientationMismatchBuilder? orientationMismatchBuilder;
  final CardScanProcessorOptions processOptions;
  final CaptureConfirmationMode cameraConfirmationMode;
  final CaptureConfirmationMode galleryConfirmationMode;
  final CardCaptureControlsConfig controls;
  final CardCaptureControlsBuilder? controlsBuilder;
  final CardCaptureLabels labels;
  final GalleryCropLabels galleryLabels;
  final ResolutionPreset resolutionPreset;
  final GalleryImagePathPicker? pickGalleryImagePath;
  final bool showGalleryShortcut;
  final CardCaptureImageCallback? onRawCaptured;
  final CardCaptureImageCallback? onCropReady;
  final CardCaptureResultCallback onCompleted;
  final VoidCallback? onClose;

  @override
  State<CardCameraGalleryCaptureView> createState() =>
      _CardCameraGalleryCaptureViewState();
}

class _CardCameraGalleryCaptureViewState
    extends State<CardCameraGalleryCaptureView> {
  String? _gallerySourcePath;
  bool _pickingGallery = false;
  Object? _pickerError;

  Future<String?> _defaultPickGalleryImagePath() async {
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

  Future<void> _openGallery() async {
    if (_pickingGallery) return;
    setState(() {
      _pickingGallery = true;
      _pickerError = null;
    });

    try {
      final path = await (widget.pickGalleryImagePath ??
          _defaultPickGalleryImagePath)();
      if (path != null && mounted) {
        setState(() => _gallerySourcePath = path);
      }
    } catch (error) {
      if (mounted) setState(() => _pickerError = error);
    } finally {
      if (mounted) setState(() => _pickingGallery = false);
    }
  }

  Future<void> _completeGallery(CardCaptureResult result) async {
    await widget.onCompleted(result);
    if (mounted) setState(() => _gallerySourcePath = null);
  }

  @override
  Widget build(BuildContext context) {
    final gallerySourcePath = _gallerySourcePath;
    if (gallerySourcePath != null) {
      return CardGalleryCropView(
        key: ValueKey(gallerySourcePath),
        sourcePath: gallerySourcePath,
        processOptions: widget.processOptions,
        confirmationMode: widget.galleryConfirmationMode,
        labels: widget.galleryLabels,
        onOriginalReady: widget.onRawCaptured,
        onCropReady: widget.onCropReady,
        onCompleted: _completeGallery,
        onClose: () => setState(() => _gallerySourcePath = null),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CardCaptureView(
          controller: widget.controller,
          frame: widget.frame,
          frameStyle: widget.frameStyle,
          frameBuilder: widget.frameBuilder,
          orientationPolicy: widget.orientationPolicy,
          orientationMismatchBuilder: widget.orientationMismatchBuilder,
          processOptions: widget.processOptions,
          confirmationMode: widget.cameraConfirmationMode,
          controls: widget.controls,
          controlsBuilder: widget.controlsBuilder,
          labels: widget.labels,
          resolutionPreset: widget.resolutionPreset,
          onRawCaptured: widget.onRawCaptured,
          onCropReady: widget.onCropReady,
          onCompleted: widget.onCompleted,
          onClose: widget.onClose,
        ),
        if (widget.showGalleryShortcut)
          _GalleryShortcut(
            busy: _pickingGallery,
            tooltip: widget.galleryLabels.pickAction,
            onPressed: _openGallery,
          ),
        if (_pickerError != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(72, 0, 72, 92),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${widget.galleryLabels.errorPrefix}: $_pickerError',
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GalleryShortcut extends StatelessWidget {
  const _GalleryShortcut({
    required this.busy,
    required this.tooltip,
    required this.onPressed,
  });

  final bool busy;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return SafeArea(
      child: Align(
        alignment: landscape ? Alignment.bottomCenter : Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: landscape ? 0 : 18,
            bottom: landscape ? 18 : 24,
          ),
          child: IconButton.filledTonal(
            onPressed: busy ? null : onPressed,
            tooltip: tooltip,
            icon: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_outlined),
          ),
        ),
      ),
    );
  }
}
