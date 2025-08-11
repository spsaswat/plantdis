import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/image_model.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';
import 'package:flutter_test_application_1/views/widgets/segment_hero_widget.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';
import 'dart:async'; // Import for TimeoutException

import '../../data/constants.dart';

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
  Future<String?>? _imageUrlFuture;
  String? _heroTag;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _heroTag = widget.imageId ?? widget.plantId + UniqueKey().toString();
    if (widget.imageId != null) {
      _imageUrlFuture = _fetchImageUrl(widget.plantId, widget.imageId!);
    }
  }

  Future<String?> _fetchImageUrl(String plantId, String imageId) async {
    try {
      List<ImageModel> images = await _plantService.getPlantImages(plantId);
      var imageMatch =
          images.where((img) => img.imageId == imageId).firstOrNull;
      return imageMatch?.originalUrl;
    } catch (e) {
      print('Error fetching image URL for CardWidget ($plantId/$imageId): $e');
      return null;
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (_isDeleting) return; // Prevent multiple deletion attempts

    final bool confirm = await UIUtils.showConfirmationDialog(
      context: context,
      title: 'Delete Item',
      message:
          'Are you sure you want to delete this ${widget.completed ? 'result' : 'processing item'}? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Colors.red,
    );

    if (confirm) {
      _deletePlant(context);
    }
  }

  Future<void> _deletePlant(BuildContext context) async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      // Show the auto-dismissing deletion dialog
      if (mounted) {
        UIUtils.showDeletionDialog(
          context,
          'Deleting item...\nDeletion will continue in the background.',
          timeoutSeconds: 3, // Show briefly
        );
      }

      // Notify parent immediately to refresh the list
      if (widget.onDelete != null) {
        widget.onDelete!();
      }

      // Start deletion in background immediately
      _plantService.deletePlant(widget.plantId).catchError((e) {
        // Log background errors but don't bother the user
        print("Background deletion error (CardWidget, ignored): $e");
      });

      // Reset deleting state immediately after triggering background task
      // The visual feedback is the dialog and the item disappearing from the list.
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    } catch (e) {
      // Handle any errors *before* deletion starts (e.g., showing dialog failed)
      if (mounted) {
        UIUtils.showErrorSnackBar(context, 'Failed to initiate deletion: $e');
      }
      // Ensure state is reset even if dialog fails
      if (mounted) {
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
          onTap:
              widget.completed && _imageUrlFuture != null
                  ? () async {
                    String? resolvedImgSrc = await _imageUrlFuture;
                    if (resolvedImgSrc != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => SegmentPage(
                                imgSrc: resolvedImgSrc,
                                id: _heroTag!,
                                plantId: widget.plantId,
                              ),
                        ),
                      );
                    }
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
                          return Image.asset(
                            'assets/images/error_icon.png',
                            fit: BoxFit.cover,
                          );
                        }

                        final imageUrl = snapshot.data!;
                        final imageWidget = Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value:
                                      loadingProgress.expectedTotalBytes != null
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
                            return Image.asset(
                              'assets/images/error_icon.png',
                              fit: BoxFit.cover,
                            );
                          },
                        );

                        if (widget.completed) {
                          return SegmentHero(imgSrc: imageUrl, id: _heroTag!);
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
                        _isDeleting ? Colors.grey : Colors.red.withValues(alpha: 0.7),
                  ),
                  // Disable button while _isDeleting is true
                  onPressed: _isDeleting ? null : () => _confirmDelete(context),
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
