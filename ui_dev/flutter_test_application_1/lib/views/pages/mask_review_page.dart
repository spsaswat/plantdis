import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/views/widgets/mask_editor_canvas.dart';
import 'package:flutter_test_application_1/views/widgets/mask_editor_controller.dart';

/// Review and edit the masks loaded from a SAM `.npy` file before processing.
///
/// Pops a [BatchSegmentationRequest] whose labels are the mask bounding boxes,
/// index-aligned with the masks themselves, so the rest of the batch pipeline
/// is reused unchanged.
class MaskReviewPage extends StatefulWidget {
  const MaskReviewPage({
    required this.imageId,
    required this.plantId,
    required this.imageUrl,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.initialMasks,
    this.droppedEmptyCount = 0,
    super.key,
  });

  final String imageId;
  final String plantId;
  final String imageUrl;
  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final List<LeafMask> initialMasks;

  /// All-zero instances skipped while reading the file, surfaced so the count
  /// shown here can be reconciled with the file the user picked.
  final int droppedEmptyCount;

  @override
  State<MaskReviewPage> createState() => _MaskReviewPageState();
}

class _MaskReviewPageState extends State<MaskReviewPage> {
  late final MaskEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MaskEditorController(
      imageWidth: widget.imageWidth,
      imageHeight: widget.imageHeight,
      initialMasks: widget.initialMasks,
    );
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _deleteSelected() async {
    final selected = _controller.selected;
    if (selected == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete this mask?'),
            content: const Text(
              'The region will not be analyzed. You can undo this.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed ?? false) _controller.removeMask(selected.id);
  }

  void _process() {
    final masks = _controller.buildFinalMasks();
    if (masks.isEmpty) return;
    Navigator.of(context).pop(
      BatchSegmentationRequest(
        imageId: widget.imageId,
        plantId: widget.plantId,
        imageUrl: widget.imageUrl,
        labels: [
          for (final mask in masks)
            mask.toNormalizedRect(widget.imageWidth, widget.imageHeight),
        ],
        masks: masks,
        localImageBytes: widget.imageBytes,
        imageWidth: widget.imageWidth,
        imageHeight: widget.imageHeight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = _controller.maskCount;
    final hasSelection = _controller.selected != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review segmentation masks'),
        actions: [
          IconButton(
            key: const Key('undo-mask-button'),
            onPressed: _controller.canUndo ? _controller.undo : null,
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: MaskEditorCanvas(
                      imageBytes: widget.imageBytes,
                      imageWidth: widget.imageWidth,
                      imageHeight: widget.imageHeight,
                      controller: _controller,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    count == 1 ? '1 mask' : '$count masks',
                    key: const Key('mask-count'),
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusLine(hasSelection),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: SegmentedButton<MaskTool>(
                      key: const Key('mask-tool-selector'),
                      segments: const [
                        ButtonSegment(
                          value: MaskTool.pan,
                          icon: Icon(Icons.pan_tool_outlined),
                          label: Text('Pan'),
                        ),
                        ButtonSegment(
                          value: MaskTool.paint,
                          icon: Icon(Icons.brush),
                          label: Text('Paint'),
                        ),
                        ButtonSegment(
                          value: MaskTool.erase,
                          icon: Icon(Icons.auto_fix_normal),
                          label: Text('Erase'),
                        ),
                      ],
                      selected: {_controller.tool},
                      onSelectionChanged:
                          (selection) => _controller.setTool(selection.first),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 12),
                      Expanded(
                        child: Slider(
                          key: const Key('brush-size-slider'),
                          min: 2,
                          max: 200,
                          value: _controller.brushRadiusImagePx.clamp(2, 200),
                          label: '${_controller.brushRadiusImagePx.round()} px',
                          onChanged: _controller.setBrushRadius,
                        ),
                      ),
                      const Icon(Icons.circle, size: 24),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('add-mask-button'),
                        onPressed: _controller.addEmptyMask,
                        icon: const Icon(Icons.add),
                        label: const Text('Add mask'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('delete-mask-button'),
                        onPressed: hasSelection ? _deleteSelected : null,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete selected'),
                      ),
                      FilledButton.icon(
                        key: const Key('process-masks-button'),
                        onPressed:
                            _controller.hasUsableMasks ? _process : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Process'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLine(bool hasSelection) {
    if (!_controller.hasUsableMasks) {
      return 'Add at least one mask before processing.';
    }
    final dropped = widget.droppedEmptyCount;
    final droppedNote =
        dropped == 0
            ? ''
            : dropped == 1
            ? ' (1 empty mask in the file was ignored)'
            : ' ($dropped empty masks in the file were ignored)';
    if (!hasSelection) {
      return 'Tap a mask to select it, then paint or erase to adjust it.'
          '$droppedNote';
    }
    return 'Each mask becomes one leaf.$droppedNote';
  }
}
