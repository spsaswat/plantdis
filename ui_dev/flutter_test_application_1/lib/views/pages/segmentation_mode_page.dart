import 'dart:typed_data';

import 'package:flutter/material.dart';

enum SegmentationMode { manual, automatic }

class SegmentationModePage extends StatelessWidget {
  const SegmentationModePage({required this.imageBytes, super.key});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose segmentation mode')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: 'Selected drone image preview',
                    image: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 7,
                        child: Image.memory(imageBytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'How would you like to identify the regions to process?',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Draw the regions yourself, or load a SAM mask file (.npy) generated for this image.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const Key('manual-segmentation-button'),
                    onPressed:
                        () =>
                            Navigator.of(context).pop(SegmentationMode.manual),
                    icon: const Icon(Icons.crop_free),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Manual segmentation'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('automatic-segmentation-button'),
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pop(SegmentationMode.automatic),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Automatic segmentation (from SAM masks)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
