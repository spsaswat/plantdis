import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/services/database_service.dart';
import 'package:flutter_test_application_1/services/auth_service.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';
import 'dart:async'; // Import for TimeoutException

class ImageCard extends StatelessWidget {
  final Map<String, dynamic> imageData;
  final Function? onDelete;
  final Function? onTap;
  final bool showDetails;

  const ImageCard({
    Key? key,
    required this.imageData,
    this.onDelete,
    this.onTap,
    this.showDetails = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = imageData['downloadUrl'] as String?;
    final uploadTime =
        imageData['uploadTime'] != null
            ? (imageData['uploadTime'] as dynamic).toDate()
            : DateTime.now();
    final status = imageData['processingStatus'] as String? ?? 'pending';
    final plantType = imageData['plantType'] as String? ?? 'Unknown';
    final imageId = imageData['id'] as String?;

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap != null ? () => onTap!(imageData) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                // Image
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child:
                      imageUrl != null
                          ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                          : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              );
                            },
                          )
                          : Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[600],
                                size: 40,
                              ),
                            ),
                          ),
                ),

                // Status indicator
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // Delete button
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete, color: Colors.white),
                      iconSize: 20,
                      constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      onPressed: () => _confirmDelete(context, imageId),
                    ),
                  ),
                ),
              ],
            ),
            if (showDetails)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plantType,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Uploaded: ${_formatDate(uploadTime)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return 'Unknown';
    }
  }

  void _confirmDelete(BuildContext context, String? imageId) {
    if (imageId == null) return;

    UIUtils.showConfirmationDialog(
      context: context,
      title: 'Delete Image',
      message:
          'Are you sure you want to delete this image? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Colors.red,
    ).then((confirmed) {
      if (confirmed) {
        _deleteImage(context, imageId);
      }
    });
  }

  Future<void> _deleteImage(BuildContext context, String imageId) async {
    // Note: ImageCard is StatelessWidget, so no internal _isDeleting state.

    try {
      // Show the auto-dismissing deletion dialog
      UIUtils.showDeletionDialog(
        context,
        'Deleting image...\nDeletion will continue in the background.',
        timeoutSeconds: 3, // Show briefly
      );

      // Notify parent immediately to refresh the list
      // Add a small delay so the dialog has a chance to appear briefly
      Future.delayed(Duration(milliseconds: 50), () {
        if (onDelete != null) {
          onDelete!();
        }
      });

      // Start deletion in background immediately
      final databaseService = DatabaseService();
      databaseService.deleteImage(imageId).catchError((e) {
        // Log background errors but don't bother the user
        print("Background deletion error (ImageCard, ignored): $e");
      });

      // No state to reset here
    } catch (e) {
      // Handle any errors *before* deletion starts (e.g., showing dialog failed)
      if (context.mounted) {
        UIUtils.showErrorSnackBar(context, 'Failed to initiate deletion: $e');
      }
    }
  }
}
