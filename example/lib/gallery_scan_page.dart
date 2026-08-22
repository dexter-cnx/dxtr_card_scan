import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'background_scan_tasks.dart';
import 'processed_preview_page.dart';

class GalleryScanPage extends StatefulWidget {
  const GalleryScanPage({super.key});

  @override
  State<GalleryScanPage> createState() => _GalleryScanPageState();
}

class _GalleryScanPageState extends State<GalleryScanPage> {
  ImageCropSelection? _selection;
  bool _busy = false;
  bool _allowPop = false;
  Object? _error;
  String? _status;

  Future<void> _leave() async {
    if (_busy || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _pick() async {
    if (_busy) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    setState(() {
      _busy = true;
      _status = 'Preparing image…';
      _error = null;
    });

    try {
      final prepared = await prepareImageInBackground(picked.path);
      if (!mounted) return;
      setState(() {
        _selection = ImageCropSelection(
          imagePath: prepared.path,
          normalizedRect: const NormalizedRect(
            left: .06,
            top: .06,
            right: .94,
            bottom: .94,
          ),
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _process() async {
    final selection = _selection;
    if (selection == null || _busy) return;

    setState(() {
      _busy = true;
      _status = 'Detecting and rectifying card…';
      _error = null;
    });

    try {
      final result = await processScanInBackground(
        imagePath: selection.imagePath,
        roi: selection.normalizedRect,
        autoDetect: true,
        enhanceForOcr: false,
        warpLongEdge: 1600,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProcessedPreviewPage(
            bytes: result,
            title: 'Gallery scanned output',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
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
    final selection = _selection;
    return PopScope(
      canPop: _allowPop,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: _busy ? null : _leave,
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
          title: const Text('Gallery crop'),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (selection != null)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Keep the whole card inside the crop. The processor will detect the card edges and correct perspective inside this area.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: selection == null
                      ? const Center(
                          child: Text('Pick an image to begin.'),
                        )
                      : ImageCropView(
                          imagePath: selection.imagePath,
                          initialRect: selection.normalizedRect,
                          onChanged: (value) => _selection = value,
                        ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Processor error: $_error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _pick,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              selection == null ? 'Pick image' : 'Pick another',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                selection == null || _busy ? null : _process,
                            icon: const Icon(Icons.document_scanner_outlined),
                            label: const Text('Scan selection'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_busy)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: .72),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(_status ?? 'Working…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
