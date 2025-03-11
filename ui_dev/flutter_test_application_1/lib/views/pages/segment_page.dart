import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/views/widgets/segment_widget.dart';

class SegmentPage extends StatelessWidget {
  const SegmentPage({super.key, required this.imgSrc});

  final String imgSrc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [SegmentWidget(imgSrc: imgSrc), Text("Segment Page")],
          ),
        ),
      ),
    );
  }
}
