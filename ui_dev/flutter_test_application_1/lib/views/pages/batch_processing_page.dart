import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/drone_batch_model.dart';
import 'package:flutter_test_application_1/services/batch_processing_service.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';
import 'package:flutter_test_application_1/views/pages/drone_result_page.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/centered_page_body.dart';
import 'package:flutter_test_application_1/views/widgets/leaf_region_overlay.dart';

/// Runs a labelled drone image through the batch pipeline, showing
/// `completed / total` progress, then hands off to the drone result page.
class BatchProcessingPage extends StatefulWidget {
  const BatchProcessingPage({required this.request, super.key});

  final BatchSegmentationRequest request;

  @override
  State<BatchProcessingPage> createState() => _BatchProcessingPageState();
}

class _BatchProcessingPageState extends State<BatchProcessingPage> {
  final BatchProcessingRunner _runner = BatchProcessingRunner();
  StreamSubscription<BatchProgress>? _subscription;

  BatchProgress? _progress;
  bool _cancelRequested = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Subscribe before starting so the first emission is not dropped by the
    // broadcast controller.
    _subscription = _runner.progress.listen(_onProgress);
    unawaited(_runner.run(widget.request));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _runner.dispose();
    super.dispose();
  }

  void _onProgress(BatchProgress progress) {
    if (!mounted) return;
    setState(() => _progress = progress);
    if (progress.done) _onFinished(progress);
  }

  void _onFinished(BatchProgress progress) {
    if (_navigated) return;
    _navigated = true;

    final batch = progress.batch;
    if (batch == null || batch.status == BatchStatus.error) {
      UIUtils.showErrorSnackBar(
        context,
        'Batch processing failed: ${progress.error ?? 'unknown error'}',
      );
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DroneResultPage(batchId: batch.batchId),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final confirmed = await UIUtils.showConfirmationDialog(
      context: context,
      title: 'Stop processing?',
      message:
          'Leaves already analyzed are kept, and the rest are left unprocessed. '
          'The current leaf finishes first.',
      confirmText: 'Stop',
      cancelText: 'Keep going',
    );
    if (!confirmed || !mounted) return;
    setState(() => _cancelRequested = true);
    _runner.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final total = progress?.total ?? widget.request.labels.length;
    final finished = progress?.finished ?? 0;
    final entries = progress?.batch?.leaves ?? const <BatchLeafEntry>[];
    final isRunning = progress?.done != true;

    return PopScope(
      canPop: !isRunning,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !isRunning) return;
        unawaited(_confirmCancel());
      },
      child: Scaffold(
        appBar: const AppbarWidget(),
        body: SafeArea(
          child: CenteredPageBody(
            children: [
              _buildOverlay(entries, progress),
              const SizedBox(height: 20),
              _buildCounter(context, finished, total),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total == 0 ? null : finished / total,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _statusLine(progress),
                key: const Key('batch-status-line'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (isRunning)
                OutlinedButton.icon(
                  key: const Key('batch-cancel-button'),
                  onPressed: _cancelRequested ? null : _confirmCancel,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(
                    _cancelRequested ? 'Stopping…' : 'Stop processing',
                  ),
                ),
              const SizedBox(height: 20),
              const Divider(),
              ...entries.map(_buildLeafTile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(List<BatchLeafEntry> entries, BatchProgress? progress) {
    return LeafRegionFrame(
      image: plantImageProvider(
        widget.request.imageUrl,
        bytes: widget.request.localImageBytes,
      ),
      imageAspectRatio:
          widget.request.imageHeight == 0
              ? 4 / 3
              : widget.request.imageWidth / widget.request.imageHeight,
      maxHeight: 280,
      entries: entries.isEmpty ? _placeholderEntries() : entries,
      activeIndex: progress?.done == true ? null : progress?.currentIndex,
    );
  }

  /// Boxes to draw before the batch record exists (first frame only).
  List<BatchLeafEntry> _placeholderEntries() {
    return [
      for (var i = 0; i < widget.request.labels.length; i++)
        BatchLeafEntry(
          labelId: 'label_${i + 1}',
          index: i,
          region: widget.request.labels[i],
        ),
    ];
  }

  Widget _buildCounter(BuildContext context, int finished, int total) {
    return Text(
      '$finished / $total',
      key: const Key('batch-progress-counter'),
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  String _statusLine(BatchProgress? progress) {
    if (progress == null) return 'Starting…';
    if (progress.done) {
      return progress.cancelled ? 'Stopped' : 'Finished — opening results…';
    }
    final failed = progress.failed;
    final stage = progress.stageMessage ?? 'Working…';
    return failed == 0 ? stage : '$stage · $failed failed';
  }

  Widget _buildLeafTile(BatchLeafEntry entry) {
    final scheme = Theme.of(context).colorScheme;
    final color = leafStatusColor(entry, scheme);

    final Widget leading;
    switch (entry.status) {
      case LeafStatus.completed:
        leading = Icon(Icons.check_circle, color: color);
      case LeafStatus.error:
        leading = Icon(Icons.error_outline, color: color);
      case LeafStatus.processing:
        leading = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        );
      default:
        leading = Icon(Icons.schedule, color: color);
    }

    final String subtitle;
    if (entry.isFailed) {
      subtitle = entry.errorMessage ?? 'Failed';
    } else if (entry.isCompleted) {
      subtitle = UIUtils.formatDiseaseName(entry.detectedDisease ?? 'Analyzed');
    } else {
      subtitle = 'Waiting';
    }

    return ListTile(
      dense: true,
      leading: leading,
      title: Text(entry.displayName),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
