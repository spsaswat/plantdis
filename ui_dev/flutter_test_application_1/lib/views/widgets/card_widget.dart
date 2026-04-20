import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_test_application_1/models/image_model.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';
import 'package:flutter_test_application_1/views/widgets/segment_hero_widget.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';
import 'package:flutter_test_application_1/utils/local_path_utils.dart';
import 'dart:async'; // Import for TimeoutException

import '../../data/constants.dart';
import '../../utils/logger.dart';

class CardWidget extends StatefulWidget {
  const CardWidget({
    super.key,
    required this.title,
    required this.description,
    required this.completed,
    this.imageId,
    required this.plantId,
    this.onDelete,
  });

  final String title;
  final String description;
  final bool completed;
  final String? imageId;
  final String plantId;
  final Function? onDelete;

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget> {
  final PlantService _plantService = PlantService();
  final LocalGuestService _localGuestService = LocalGuestService();
  Future<String?>? _imageUrlFuture;
  /// Logged-in only: Hero + legacy SegmentPage id (imageId or plantId+UniqueKey).
  String? _heroTag;
  bool _isDeleting = false;

  bool get _guest => _localGuestService.isLocalGuestMode();

  @override
  void initState() {
    super.initState();
    if (widget.imageId != null) {
      _imageUrlFuture = _fetchImageUrl(widget.plantId, widget.imageId!);
    }
    if (!_guest) {
      _heroTag = widget.imageId ?? widget.plantId + UniqueKey().toString();
    }
  }

  Future<String?> _fetchImageUrl(String plantId, String imageId) async {
    try {
      if (_localGuestService.isLocalGuestMode()) {
        final plant = await _localGuestService.getPlantById(plantId);
        return plant?.analysisResults?['localImagePath'] as String?;
      }
      List<ImageModel> images = await _plantService.getPlantImages(plantId);
      var imageMatch =
          images.where((img) => img.imageId == imageId).firstOrNull;
      return imageMatch?.originalUrl;
    } catch (e) {
      logger.e(
        'Error fetching image URL for CardWidget ($plantId/$imageId): $e',
      );
      return null;
    }
  }

  // Modified _confirmDelete to no longer take BuildContext as a parameter
  // and to use a single `mounted` check after the await call.
  Future<void> _confirmDelete() async {
    if (_isDeleting) return;

    final bool confirm = await UIUtils.showConfirmationDialog(
      context: context, // Access the State's context directly
      title: 'Delete Item',
      message:
          'Are you sure you want to delete this ${widget.completed ? 'result' : 'processing item'}? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Colors.red,
    );

    if (!mounted) {
      return;
    }

    if (confirm) {
      await _deletePlant(); // Call without passing context
    }
  }

  // Modified _deletePlant to no longer take BuildContext as a parameter.
  Future<void> _deletePlant() async {
    if (_isDeleting) return;

    // Save context reference before any async operations
    final currentContext = context;

    setState(() {
      _isDeleting = true;
    });

    try {
      // Show the auto-dismissing deletion dialog
      if (mounted) {
        UIUtils.showDeletionDialog(
          currentContext,
          'Deleting item...\nDeletion will continue in the background.',
          timeoutSeconds: 3, // Show briefly
        );
      }

      try {
        await _plantService.deletePlant(widget.plantId);
        if (widget.onDelete != null) {
          widget.onDelete!();
        }
      } catch (e, st) {
        logger.e('CardWidget deletePlant failed: $e\n$st');
        if (mounted) {
          UIUtils.showErrorSnackBar(
            currentContext,
            'Could not delete: $e',
          );
        }
      }

      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    } catch (e) {
      // This catch block only handles errors from synchronous operations
      // (like showing dialog or calling onDelete), not from async operations
      if (mounted) {
        UIUtils.showErrorSnackBar(
          currentContext,
          'Failed to initiate deletion: $e',
        );
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(10);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        color: widget.completed ? null : Colors.white12,
        child: InkWell(
          borderRadius: borderRadius,
          // Guest: pending + completed can open detail with real imageId + snackbar on failure.
          // Logged-in: unchanged — only completed cards navigate; no snackbar (silent skip).
          onTap:
              (_guest
                      ? (widget.imageId != null && _imageUrlFuture != null)
                      : (widget.completed &&
                          _imageUrlFuture != null &&
                          _heroTag != null))
                  ? () async {
                    final navigator = Navigator.of(context);
                    String? resolvedImgSrc = await _imageUrlFuture;
                    if (!mounted) return;
                    if (resolvedImgSrc == null) {
                      if (_guest) {
                        UIUtils.showErrorSnackBar(
                          context,
                          'Could not load image for this record. Try again or re-upload.',
                        );
                      }
                      return;
                    }
                    final String segmentId =
                        _guest ? widget.imageId! : _heroTag!;
                    navigator.push(
                      MaterialPageRoute(
                        builder:
                            (context) => SegmentPage(
                              imgSrc: resolvedImgSrc,
                              id: segmentId,
                              plantId: widget.plantId,
                            ),
                      ),
                    );
                  }
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                SizedBox(
                  width: 50.0,
                  height: 50.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3.0),
                    child: FutureBuilder<String?>(
                      future: _imageUrlFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data == null) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                              size: 22,
                            ),
                          );
                        }

                        final imageUrl = snapshot.data!;
                        logger.d('Image URL: $imageUrl');
                        final bool isLocalFile =
                            isLocalFilesystemPath(imageUrl);
                        logger.d('Is Local File: $isLocalFile');
                        final imageWidget = isLocalFile
                            ? Image.file(
                                File(toLocalFilePath(imageUrl)),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey,
                                      size: 22,
                                    ),
                                  );
                                },
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value:
                                            loadingProgress.expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey,
                                      size: 22,
                                    ),
                                  );
                                },
                              );

                        if (widget.completed) {
                          final heroId = _guest ? widget.imageId! : _heroTag!;
                          return SegmentHero(
                            imgSrc: imageUrl,
                            id: heroId,
                          );
                        } else {
                          return Opacity(opacity: 0.75, child: imageWidget);
                        }
                      },
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
                        Text(widget.title, style: KTextStyle.titleTealText),
                        Text(
                          widget.description,
                          style: KTextStyle.descriptionText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // Delete button
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color:
                        _isDeleting
                            ? Colors.grey
                            : Colors.red.withValues(alpha: 0.7),
                  ),
                  onPressed: _isDeleting ? null : () => _confirmDelete(),
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
