import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/views/pages/manual_label_review_page.dart';
import 'package:flutter_test_application_1/views/widgets/rectangle_label_canvas.dart';

class ManualSegmentationPage extends StatefulWidget {
  const ManualSegmentationPage({
    required this.imageId,
    required this.plantId,
    required this.imageUrl,
    required this.imageBytes,
    this.initialLabels = const [],
    this.imageSize,
    super.key,
  });

  final String imageId;
  final String plantId;
  final String imageUrl;
  final Uint8List imageBytes;
  final List<NormalizedLabelRect> initialLabels;
  final Size? imageSize;

  @override
  State<ManualSegmentationPage> createState() => _ManualSegmentationPageState();
}

class _ManualSegmentationPageState extends State<ManualSegmentationPage> {
  late List<NormalizedLabelRect> _labels;
  late final Future<Size> _imageSizeFuture;
  bool _isEditingSavedLabels = false;

  @override
  void initState() {
    super.initState();
    _labels = List.of(widget.initialLabels);
    _isEditingSavedLabels = widget.initialLabels.isNotEmpty;
    _imageSizeFuture =
        widget.imageSize == null
            ? _decodeImageSize(widget.imageBytes)
            : Future.value(widget.imageSize);
  }

  Future<Size> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } finally {
      codec.dispose();
    }
  }

  void _addLabel(NormalizedLabelRect label) {
    setState(() => _labels = [..._labels, label]);
  }

  void _undoLastLabel() {
    if (_labels.isEmpty || _isEditingSavedLabels) return;
    setState(() => _labels = _labels.sublist(0, _labels.length - 1));
  }

  Future<void> _clearLabels() async {
    if (_labels.isEmpty) return;
    final shouldClear = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear all labels?'),
            content: const Text('This removes every box from the image.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Clear all'),
              ),
            ],
          ),
    );
    if (shouldClear == true && mounted) {
      setState(() => _labels = []);
    }
  }

  Future<void> _review(Size imageSize) async {
    final result = await Navigator.of(context).push<ManualLabelReviewResult>(
      MaterialPageRoute(
        builder:
            (context) => ManualLabelReviewPage(
              imageId: widget.imageId,
              plantId: widget.plantId,
              imageUrl: widget.imageUrl,
              imageBytes: widget.imageBytes,
              imageWidth: imageSize.width.round(),
              imageHeight: imageSize.height.round(),
              labels: List.unmodifiable(_labels),
            ),
      ),
    );
    if (!mounted || result == null) return;

    switch (result.action) {
      case ManualLabelReviewAction.edit:
        setState(() => _isEditingSavedLabels = true);
        return;
      case ManualLabelReviewAction.process:
        Navigator.of(context).pop(result.request);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditingSavedLabels ? 'Edit manual labels' : 'Manual segmentation',
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<Size>(
          future: _imageSizeFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to open the selected image: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final imageSize = snapshot.data;
            if (imageSize == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Drag on the image to draw a box around each region.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: RectangleLabelCanvas(
                          imageBytes: widget.imageBytes,
                          imageAspectRatio: imageSize.width / imageSize.height,
                          labels: List.unmodifiable(_labels),
                          onLabelCreated: _addLabel,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_labels.length} ${_labels.length == 1 ? 'label' : 'labels'}',
                    key: const Key('manual-label-count'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('undo-label-button'),
                        onPressed:
                            _labels.isEmpty || _isEditingSavedLabels
                                ? null
                                : _undoLastLabel,
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo last'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('clear-labels-button'),
                        onPressed: _labels.isEmpty ? null : _clearLabels,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Clear all'),
                      ),
                      FilledButton.icon(
                        key: const Key('save-labels-button'),
                        onPressed: () => _review(imageSize),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
