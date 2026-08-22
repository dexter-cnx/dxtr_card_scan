import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProcessedPreviewPage extends StatelessWidget {
  const ProcessedPreviewPage({
    required this.bytes,
    this.title = 'Processed output',
    super.key,
  });

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ColoredBox(
        color: Colors.black,
        child: Center(
          child: InteractiveViewer(
            minScale: .5,
            maxScale: 6,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
