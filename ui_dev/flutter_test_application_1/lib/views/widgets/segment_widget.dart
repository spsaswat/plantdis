import 'package:flutter/material.dart';

class SegmentWidget extends StatelessWidget {
  const SegmentWidget({super.key, required this.imgSrc});

  final String imgSrc;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'segmentHero',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.0),
        child: Image.asset(
          imgSrc,
          width: double.infinity,
        ),
      ),
    );
  }
}
