import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:flutter/material.dart';

class SegmentHero extends StatelessWidget {
  const SegmentHero({super.key, required this.imgSrc, required this.id});

  final String imgSrc;
  final String id;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: id,
      child: AspectRatio(
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
    );
  }
}
