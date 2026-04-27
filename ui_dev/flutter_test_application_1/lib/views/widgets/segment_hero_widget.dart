import 'dart:io';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/utils/local_path_utils.dart';

class SegmentHero extends StatelessWidget {
  const SegmentHero({
    super.key,
    required this.imgSrc,
    required this.id,
    this.segmentationFile,
  });

  final String imgSrc;
  final String id;
  final File? segmentationFile;

  static const Widget _missingLocal = Center(
    child: Icon(
      Icons.broken_image_outlined,
      color: Colors.grey,
      size: 48,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isLocalFile = isLocalFilesystemPath(imgSrc);
    final localPath = toLocalFilePath(imgSrc);
    final localFile = isLocalFile ? File(localPath) : null;
    final localMissing = isLocalFile && !(localFile?.existsSync() ?? false);
    final ImageProvider? fullScreenProvider =
        !isLocalFile
            ? NetworkImage(imgSrc)
            : (localMissing ? null : FileImage(File(localPath)));

    return Hero(
      tag: id,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: GestureDetector(
              onTap:
                  fullScreenProvider == null
                      ? null
                      : () {
                          showImageViewer(
                            context,
                            fullScreenProvider,
                            swipeDismissible: true,
                            doubleTapZoomable: true,
                            onViewerDismissed: () {},
                          );
                        },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5.0),
                child: isLocalFile
                    ? (localMissing
                        ? _missingLocal
                        : Image.file(
                            File(localPath),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _missingLocal,
                          ))
                    : Image.network(
                        imgSrc,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),

          // Display segmentation result if available
          if (segmentationFile != null) ...[
            const SizedBox(height: 10),
            const Text(
              "Segmentation Result",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Builder(
              builder: (context) {
                final seg = segmentationFile!;
                final segMissing = !seg.existsSync();
                final segProvider =
                    segMissing ? null : FileImage(seg);
                return AspectRatio(
                  aspectRatio: 16 / 9,
                  child: GestureDetector(
                    onTap:
                        segProvider == null
                            ? null
                            : () {
                              showImageViewer(
                                context,
                                segProvider,
                                swipeDismissible: true,
                                doubleTapZoomable: true,
                                onViewerDismissed: () {},
                              );
                            },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5.0),
                      child: segMissing
                          ? _missingLocal
                          : Image.file(
                              seg,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _missingLocal,
                            ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
