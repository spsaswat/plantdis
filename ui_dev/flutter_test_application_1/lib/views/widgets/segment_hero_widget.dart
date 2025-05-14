import 'dart:io';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: id,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: GestureDetector(
              onTap: () {
                showImageViewer(
                  context,
                  Image.network(imgSrc).image,
                  swipeDismissible: true,
                  doubleTapZoomable: true,
                  onViewerDismissed: () {},
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5.0),
                child: Image.network(
                  imgSrc,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Display segmentation result if available
          if (segmentationFile != null) ...[
            SizedBox(height: 10),
            Text(
              "Segmentation Result",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 5),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: GestureDetector(
                onTap: () {
                  showImageViewer(
                    context,
                    Image.file(segmentationFile!).image,
                    swipeDismissible: true,
                    doubleTapZoomable: true,
                    onViewerDismissed: () {},
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: Image.file(
                    segmentationFile!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
