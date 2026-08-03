import 'package:flutter/material.dart';

import 'package:flutter_test_application_1/data/constants.dart';
import 'package:flutter_test_application_1/models/drone_batch_model.dart';
import 'package:flutter_test_application_1/services/drone_batch_service.dart';
import 'package:flutter_test_application_1/utils/logger.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';
import 'package:flutter_test_application_1/views/pages/drone_result_page.dart';
import 'package:flutter_test_application_1/views/widgets/leaf_region_overlay.dart';

/// Home/Results list tile for a drone image processed as a batch.
///
/// Deliberately mirrors `CardWidget`'s layout so the two card types sit
/// together in the same list without looking out of place.
class BatchCardWidget extends StatefulWidget {
  const BatchCardWidget({required this.batch, this.onDelete, super.key});

  final DroneBatchModel batch;
  final VoidCallback? onDelete;

  @override
  State<BatchCardWidget> createState() => _BatchCardWidgetState();
}

class _BatchCardWidgetState extends State<BatchCardWidget> {
  final DroneBatchService _batchService = DroneBatchService();
  bool _isDeleting = false;

  DroneBatchModel get _batch => widget.batch;

  String get _description {
    if (!_batch.isFinished) {
      return 'Processing ${_batch.finishedCount}/${_batch.totalCount} leaves';
    }
    final summary = _batch.summary;
    if (summary == null || summary.analyzedCount == 0) {
      return 'No leaves could be analyzed';
    }
    final parts = <String>[
      '${summary.diseasedCount} diseased',
      '${summary.healthyCount} healthy',
    ];
    if (_batch.failedCount > 0) parts.add('${_batch.failedCount} failed');
    return parts.join(' · ');
  }

  Future<void> _confirmDelete() async {
    if (_isDeleting) return;
    final confirmed = await UIUtils.showConfirmationDialog(
      context: context,
      title: 'Delete Item',
      message:
          'Are you sure you want to delete this drone result and its '
          '${_batch.totalCount} leaf results? This action cannot be undone.',
      confirmText: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _batchService.deleteBatch(_batch.batchId);
      widget.onDelete?.call();
    } catch (e, st) {
      logger.e('[BatchCardWidget] Delete failed: $e\n$st');
      if (mounted) UIUtils.showErrorSnackBar(context, 'Could not delete: $e');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(10);
    final thumbnail = plantImageProvider(_batch.originalImageUrl);
    final completed = _batch.isFinished;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        color: completed ? null : Colors.white12,
        child: InkWell(
          borderRadius: borderRadius,
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => DroneResultPage(batchId: _batch.batchId),
                ),
              ),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                SizedBox(
                  width: 50.0,
                  height: 50.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3.0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumbnail == null)
                          const ColoredBox(
                            color: Colors.black26,
                            child: Icon(
                              Icons.flight_takeoff,
                              size: 22,
                              color: Colors.grey,
                            ),
                          )
                        else
                          Image(
                            image: thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey,
                                    size: 22,
                                  ),
                                ),
                          ),
                        // Marks this row as a multi-leaf drone result.
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            color: Colors.black87,
                            child: Text(
                              '${_batch.totalCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Drone Image · ${_batch.totalCount} leaves',
                          style: KTextStyle.titleTealText,
                        ),
                        Text(
                          _description,
                          style: KTextStyle.descriptionText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color:
                        _isDeleting
                            ? Colors.grey
                            : Colors.red.withValues(alpha: 0.7),
                  ),
                  onPressed: _isDeleting ? null : _confirmDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
