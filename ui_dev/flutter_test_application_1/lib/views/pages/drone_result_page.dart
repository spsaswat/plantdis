import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_test_application_1/data/constants.dart';
import 'package:flutter_test_application_1/models/drone_batch_model.dart';
import 'package:flutter_test_application_1/services/drone_batch_service.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/centered_page_body.dart';
import 'package:flutter_test_application_1/views/widgets/leaf_region_overlay.dart';

/// Result page for a drone image processed as a batch.
///
/// Shows the batch summary and links out to each leaf's normal result page.
class DroneResultPage extends StatefulWidget {
  const DroneResultPage({required this.batchId, super.key});

  final String batchId;

  @override
  State<DroneResultPage> createState() => _DroneResultPageState();
}

class _DroneResultPageState extends State<DroneResultPage> {
  final DroneBatchService _batchService = DroneBatchService();
  late final Stream<DroneBatchModel?> _batchStream;

  @override
  void initState() {
    super.initState();
    _batchStream = _batchService.batchStream(widget.batchId);
  }

  void _openLeaf(BatchLeafEntry entry) {
    final plantId = entry.leafPlantId;
    final imageId = entry.leafImageId;
    final imgSrc = entry.croppedImageUrl;
    if (plantId == null || imageId == null || imgSrc == null) {
      UIUtils.showErrorSnackBar(
        context,
        entry.isFailed
            ? 'This leaf could not be analyzed: ${entry.errorMessage ?? 'unknown error'}'
            : 'This leaf has no saved result yet.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) =>
                SegmentPage(imgSrc: imgSrc, id: imageId, plantId: plantId),
      ),
    );
  }

  Future<void> _confirmDelete(DroneBatchModel batch) async {
    final confirmed = await UIUtils.showConfirmationDialog(
      context: context,
      title: 'Delete drone result',
      message:
          'This deletes the drone image result and all ${batch.totalCount} leaf '
          'results it created. This action cannot be undone.',
      confirmText: 'Delete',
    );
    if (!confirmed || !mounted) return;

    final navigator = Navigator.of(context);
    try {
      await _batchService.deleteBatch(batch.batchId);
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      UIUtils.showErrorSnackBar(context, 'Could not delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppbarWidget(),
      body: SafeArea(
        child: StreamBuilder<DroneBatchModel?>(
          stream: _batchStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final batch = snapshot.data;
            if (batch == null) {
              return const Center(
                child: Text('This drone result is no longer available.'),
              );
            }
            return _buildBody(batch);
          },
        ),
      ),
    );
  }

  Widget _buildBody(DroneBatchModel batch) {
    return CenteredPageBody(
      children: [
        const Text('Drone Image Result', style: KTextStyle.titleTealText),
        const SizedBox(height: 4),
        Text(
          _formatTimestamp(batch.updatedAt ?? batch.createdAt),
          style: KTextStyle.descriptionText,
        ),
        const SizedBox(height: 16),
        _buildOverlay(batch),
        const SizedBox(height: 8),
        Text(
          'Tap a box to open that leaf.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        _buildSummaryCard(batch),
        const SizedBox(height: 16),
        if (batch.summary?.recommendation != null)
          _buildRecommendationCard(batch.summary!.recommendation!),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Leaves (${batch.totalCount})',
            style: KTextStyle.titleTealText,
          ),
        ),
        const Divider(),
        ...batch.leaves.map(_buildLeafTile),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => _confirmDelete(batch),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          label: const Text(
            'Delete Result',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay(DroneBatchModel batch) {
    return LeafRegionFrame(
      image: plantImageProvider(batch.originalImageUrl),
      imageAspectRatio:
          batch.imageHeight == 0 ? 4 / 3 : batch.imageWidth / batch.imageHeight,
      entries: batch.leaves,
      onLeafTap: _openLeaf,
    );
  }

  Widget _buildSummaryCard(DroneBatchModel batch) {
    final summary = batch.summary;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary', style: KTextStyle.titleTealText),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statTile('Leaves', '${batch.totalCount}', scheme.primary),
                _statTile(
                  'Healthy',
                  '${summary?.healthyCount ?? 0}',
                  Colors.green,
                ),
                _statTile(
                  'Diseased',
                  '${summary?.diseasedCount ?? 0}',
                  Colors.orange,
                ),
                if (batch.failedCount > 0)
                  _statTile('Failed', '${batch.failedCount}', scheme.error),
              ],
            ),
            const SizedBox(height: 16),
            _summaryRow('Status', _statusLabel(batch.status)),
            if (summary?.dominantDisease != null)
              _summaryRow(
                'Most common',
                UIUtils.formatDiseaseName(summary!.dominantDisease!),
              ),
            if (summary?.averageConfidence != null)
              _summaryRow(
                'Average confidence',
                '${(summary!.averageConfidence! * 100).toStringAsFixed(1)}%',
              ),
            if (summary != null && summary.speciesCounts.isNotEmpty)
              _summaryRow(
                'Species',
                summary.speciesCounts.entries
                    .map((e) => '${e.key} (${e.value})')
                    .join(', '),
              ),
            if (summary != null && summary.diseaseCounts.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Breakdown', style: KTextStyle.descriptionText),
              const SizedBox(height: 6),
              ...summary.diseaseCounts.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(UIUtils.formatDiseaseName(e.key)),
                      ),
                      Text(
                        '${e.value}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: KTextStyle.descriptionText),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: KTextStyle.descriptionText),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(String recommendation) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tips_and_updates_outlined, size: 20),
                SizedBox(width: 8),
                Text('AI Suggestion', style: KTextStyle.titleTealText),
              ],
            ),
            const SizedBox(height: 10),
            Text(recommendation),
          ],
        ),
      ),
    );
  }

  Widget _buildLeafTile(BatchLeafEntry entry) {
    final scheme = Theme.of(context).colorScheme;
    final color = leafStatusColor(entry, scheme);
    final thumbnail = plantImageProvider(entry.croppedImageUrl);

    final String subtitle;
    if (entry.isFailed) {
      subtitle = entry.errorMessage ?? 'Analysis failed';
    } else if (entry.isCompleted) {
      final species = entry.plantSpecies;
      final disease = UIUtils.formatDiseaseName(entry.detectedDisease ?? '');
      subtitle = species == null ? disease : '$species · $disease';
    } else {
      subtitle = 'Not analyzed';
    }

    final confidence = entry.confidence;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: () => _openLeaf(entry),
        leading: SizedBox(
          width: 48,
          height: 48,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child:
                thumbnail == null
                    ? ColoredBox(
                      color: color.withValues(alpha: 0.15),
                      child: Icon(Icons.eco_outlined, color: color),
                    )
                    : Image(image: thumbnail, fit: BoxFit.cover),
          ),
        ),
        title: Text(entry.displayName, style: KTextStyle.titleTealText),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: KTextStyle.descriptionText,
        ),
        trailing:
            confidence == null
                ? Icon(Icons.chevron_right, color: color)
                : Chip(
                  label: Text('${(confidence * 100).toStringAsFixed(0)}%'),
                  backgroundColor: color.withValues(alpha: 0.15),
                  side: BorderSide(color: color.withValues(alpha: 0.4)),
                  visualDensity: VisualDensity.compact,
                ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case BatchStatus.completed:
        return 'Completed';
      case BatchStatus.partial:
        return 'Completed with errors';
      case BatchStatus.cancelled:
        return 'Stopped early';
      case BatchStatus.error:
        return 'Failed';
      default:
        return 'Processing';
    }
  }

  String _formatTimestamp(DateTime time) {
    return DateFormat('MMM d, yyyy h:mm a').format(time);
  }
}
