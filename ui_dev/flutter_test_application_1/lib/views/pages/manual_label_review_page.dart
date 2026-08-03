import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/views/widgets/rectangle_label_canvas.dart';

enum ManualLabelReviewAction { edit, process }

class ManualLabelReviewResult {
  const ManualLabelReviewResult.edit()
    : action = ManualLabelReviewAction.edit,
      request = null;

  const ManualLabelReviewResult.process(this.request)
    : action = ManualLabelReviewAction.process;

  final ManualLabelReviewAction action;
  final BatchSegmentationRequest? request;
}

class ManualLabelReviewPage extends StatelessWidget {
  const ManualLabelReviewPage({
    required this.imageId,
    required this.plantId,
    required this.imageUrl,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.labels,
    super.key,
  });

  final String imageId;
  final String plantId;
  final String imageUrl;
  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final List<NormalizedLabelRect> labels;

  BatchSegmentationRequest get _request => BatchSegmentationRequest(
    imageId: imageId,
    plantId: plantId,
    imageUrl: imageUrl,
    labels: List.unmodifiable(labels),
    localImageBytes: imageBytes,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );

  @override
  Widget build(BuildContext context) {
    final count = labels.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Review labels')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 360,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: RectangleLabelCanvas(
                          imageBytes: imageBytes,
                          imageAspectRatio: imageWidth / imageHeight,
                          labels: List.unmodifiable(labels),
                          enabled: false,
                          onLabelCreated: (_) {},
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Icon(
                    count == 0 ? Icons.info_outline : Icons.check_circle,
                    size: 52,
                    color:
                        count == 0
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$count ${count == 1 ? 'label' : 'labels'} ready',
                    key: const Key('label-count-summary'),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    count == 0
                        ? 'Add at least one label before processing.'
                        : 'Review the count, edit the regions if needed, then continue to batch processing.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    key: const Key('edit-labels-button'),
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pop(const ManualLabelReviewResult.edit()),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit labels'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('process-labels-button'),
                    onPressed:
                        count == 0
                            ? null
                            : () => Navigator.of(
                              context,
                            ).pop(ManualLabelReviewResult.process(_request)),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Process'),
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
