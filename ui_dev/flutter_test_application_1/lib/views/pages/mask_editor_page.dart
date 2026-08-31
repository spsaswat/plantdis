import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/views/widgets/mask_editor_canvas.dart';
import 'package:flutter_test_application_1/views/widgets/mask_editor_controller.dart';
import 'package:flutter_test_application_1/views/widgets/mask_editor_help_dialog.dart';

/// Paint, review and edit the leaf masks of a drone image before processing.
///
/// Serves both drone flows. The automatic flow opens it on the masks read from
/// a SAM `.npy` file; the manual flow opens it with [initialMasks] empty and
/// the user paints every leaf by hand. Only the wording and the recorded
/// [source] differ — the editing surface is the same one.
///
/// Pops a [BatchSegmentationRequest] whose labels are the mask bounding boxes,
/// index-aligned with the masks themselves, so the rest of the batch pipeline
/// is reused unchanged.
class MaskEditorPage extends StatefulWidget {
  const MaskEditorPage({
    required this.imageId,
    required this.plantId,
    required this.imageUrl,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.initialMasks,
    required this.source,
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

  /// Where [initialMasks] came from, recorded on the request so the batch is
  /// filed as hand-painted or SAM-derived.
  final SegmentationSource source;

  /// All-zero instances skipped while reading the file, surfaced so the count
  /// shown here can be reconciled with the file the user picked. Always 0 for
  /// the manual flow.
  final int droppedEmptyCount;

  bool get _isManual => source == SegmentationSource.manual;

  @override
  State<MaskEditorPage> createState() => _MaskEditorPageState();
}

class _MaskEditorPageState extends State<MaskEditorPage> {
  late final MaskEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MaskEditorController(
      imageWidth: widget.imageWidth,
      imageHeight: widget.imageHeight,
      initialMasks: widget.initialMasks,
    );
    if (_controller.maskCount == 0) {
      // Nothing to review yet: open with a blank mask selected and the brush
      // armed, so the first drag paints the first leaf.
      _controller.addEmptyMask(recordUndo: false);
    }
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
        source: widget.source,
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
        title: Text(
          widget._isManual ? 'Draw leaf masks' : 'Review segmentation masks',
        ),
        actions: [
          IconButton(
            key: Key(
              widget._isManual
                  ? 'mask-drawing-help-button'
                  : 'mask-review-help-button',
            ),
            onPressed:
                () =>
                    widget._isManual
                        ? showMaskDrawingHelpDialog(context)
                        : showMaskReviewHelpDialog(context),
            icon: const Icon(Icons.help_outline),
            tooltip:
                widget._isManual ? 'How to draw masks' : 'How to review masks',
          ),
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
                          value: MaskTool.paint,
                          icon: Icon(Icons.edit_outlined),
                          label: Text('Pen'),
                        ),
                        ButtonSegment(
                          value: MaskTool.erase,
                          icon: Icon(Icons.edit_off_outlined),
                          label: Text('Erase'),
                        ),
                      ],
                      selected: {_controller.tool},
                      onSelectionChanged:
                          (selection) => _controller.setTool(selection.first),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        onPressed: _controller.hasUsableMasks ? _process : null,
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
      return widget._isManual
          ? 'Draw a line round a leaf to mask it — the loop is closed and '
              'filled for you. Right-drag moves the image, the wheel zooms it.'
          : 'Add at least one mask before processing.';
    }
    final dropped = widget.droppedEmptyCount;
    final droppedNote =
        dropped == 0
            ? ''
            : dropped == 1
            ? ' (1 empty mask in the file was ignored)'
            : ' ($dropped empty masks in the file were ignored)';
    if (!hasSelection) {
      return 'Tap a mask to select it, then draw round what to add or take '
          'away. Right-drag moves the image, the wheel zooms it.$droppedNote';
    }
    return 'Draw round what to add to this mask or take out of it. Right-drag '
        'moves the image, the wheel zooms it.$droppedNote';
  }
}
