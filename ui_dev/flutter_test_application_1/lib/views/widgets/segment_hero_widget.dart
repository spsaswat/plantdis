import 'package:flutter/material.dart';

class SegmentHero extends StatelessWidget {
  const SegmentHero({super.key, required this.imgSrc, required this.id});

  final String imgSrc;
  final String id;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: id,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.0),
        child: Image.asset(imgSrc, width: double.infinity),
      ),
    );
  }
}
