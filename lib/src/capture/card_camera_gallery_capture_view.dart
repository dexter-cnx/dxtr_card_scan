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
import 'card_capture_result.dart';
import 'card_capture_view.dart';
import 'card_native_scanner.dart';

/// Unified capture surface that lets users switch between Camera, Gallery and
/// an optional host-provided native document scanner without leaving the scan
/// flow.
///
/// Gallery and native-scanner images both continue through the package-owned
/// Gallery crop and native processing pipeline. Native scanner implementations
/// remain host-injected so this package does not depend directly on a platform
/// scanner SDK.
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
    this.nativeScanner,
    this.showNativeScannerShortcut = true,
    this.nativeScannerTooltip = 'Scan document',
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

  /// Optional host-provided native document scanner fallback.
  final CardNativeScanner? nativeScanner;

  /// Whether to show the native scanner shortcut when [nativeScanner] reports
  /// that it is available.
  final bool showNativeScannerShortcut;

  /// Tooltip used by the package-owned native scanner shortcut.
  final String nativeScannerTooltip;

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
  bool _nativeScannerAvailable = false;
  bool _scanningNative = false;
  List<String> _nativeScanPaths = const [];
  int _nativeScanIndex = 0;
  Object? _pickerError;

  bool get _nativeScanActive => _nativeScanPaths.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _refreshNativeScannerAvailability();
  }

  @override
  void didUpdateWidget(CardCameraGalleryCaptureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.nativeScanner, widget.nativeScanner) ||
        oldWidget.showNativeScannerShortcut !=
            widget.showNativeScannerShortcut) {
      _cancelNativeScan();
      _refreshNativeScannerAvailability();
    }
  }

  Future<void> _refreshNativeScannerAvailability() async {
    final scanner = widget.nativeScanner;
    if (scanner == null || !widget.showNativeScannerShortcut) {
      if (mounted) setState(() => _nativeScannerAvailable = false);
      return;
    }

    try {
      final available = await scanner.isAvailable();
      if (mounted && identical(scanner, widget.nativeScanner)) {
        setState(() => _nativeScannerAvailable = available);
      }
    } catch (error) {
      if (mounted && identical(scanner, widget.nativeScanner)) {
        setState(() {
          _nativeScannerAvailable = false;
          _pickerError = error;
        });
      }
    }
  }

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
    if (_pickingGallery || _scanningNative) return;
    setState(() {
      _pickingGallery = true;
      _pickerError = null;
    });

    try {
      final path = await (widget.pickGalleryImagePath ??
          _defaultPickGalleryImagePath)();
      if (path != null && mounted) {
        _cancelNativeScan();
        setState(() => _gallerySourcePath = path);
      }
    } catch (error) {
      if (mounted) setState(() => _pickerError = error);
    } finally {
      if (mounted) setState(() => _pickingGallery = false);
    }
  }

  Future<void> _openNativeScanner() async {
    final scanner = widget.nativeScanner;
    if (scanner == null ||
        !_nativeScannerAvailable ||
        _scanningNative ||
        _pickingGallery) {
      return;
    }

    setState(() {
      _scanningNative = true;
      _pickerError = null;
    });

    try {
      final result = await scanner.scan();
      if (!mounted || !identical(scanner, widget.nativeScanner)) return;
      if (result == null) return;

      setState(() {
        _nativeScanPaths = result.imagePaths;
        _nativeScanIndex = 0;
        _gallerySourcePath = result.imagePaths.first;
      });
    } catch (error) {
      if (mounted && identical(scanner, widget.nativeScanner)) {
        setState(() => _pickerError = error);
      }
    } finally {
      if (mounted && identical(scanner, widget.nativeScanner)) {
        setState(() => _scanningNative = false);
      }
    }
  }

  void _cancelNativeScan() {
    _nativeScanPaths = const [];
    _nativeScanIndex = 0;
  }

  void _closeSourceFlow() {
    setState(() {
      _gallerySourcePath = null;
      _cancelNativeScan();
    });
  }

  Future<void> _completeGallery(CardCaptureResult result) async {
    await widget.onCompleted(result);
    if (!mounted) return;

    if (_nativeScanActive && _nativeScanIndex + 1 < _nativeScanPaths.length) {
      setState(() {
        _nativeScanIndex += 1;
        _gallerySourcePath = _nativeScanPaths[_nativeScanIndex];
      });
      return;
    }

    setState(() {
      _gallerySourcePath = null;
      _cancelNativeScan();
    });
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
        onClose: _closeSourceFlow,
      );
    }

    final sourceShortcutAvailable =
        widget.cameraConfirmationMode == CaptureConfirmationMode.none;
    final galleryShortcutAvailable =
        widget.showGalleryShortcut && sourceShortcutAvailable;
    final nativeScannerShortcutAvailable = _nativeScannerAvailable &&
        widget.showNativeScannerShortcut &&
        sourceShortcutAvailable;

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
        if (galleryShortcutAvailable)
          _SourceShortcut(
            alignment: Alignment.bottomLeft,
            busy: _pickingGallery,
            tooltip: widget.galleryLabels.pickAction,
            icon: Icons.photo_library_outlined,
            onPressed: _openGallery,
          ),
        if (nativeScannerShortcutAvailable)
          _SourceShortcut(
            alignment: Alignment.bottomRight,
            busy: _scanningNative,
            tooltip: widget.nativeScannerTooltip,
            icon: Icons.document_scanner_outlined,
            onPressed: _openNativeScanner,
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

class _SourceShortcut extends StatelessWidget {
  const _SourceShortcut({
    required this.alignment,
    required this.busy,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Alignment alignment;
  final bool busy;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.only(left: 18, right: 18, bottom: 24),
          child: IconButton.filledTonal(
            onPressed: busy ? null : onPressed,
            tooltip: tooltip,
            icon: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon),
          ),
        ),
      ),
    );
  }
}
