import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';

class SegmentWidget extends StatelessWidget {
  final File segmentationFile;
  final String title;

  const SegmentWidget({
    super.key,
    required this.segmentationFile,
    this.title = 'Segmentation Result',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                showImageViewer(
                  context,
                  Image.file(segmentationFile).image,
                  swipeDismissible: true,
                  doubleTapZoomable: true,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5.0),
                child: Image.file(
                  segmentationFile,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
