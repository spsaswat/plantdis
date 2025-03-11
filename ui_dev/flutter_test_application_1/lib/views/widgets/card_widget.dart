import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';

import '../../data/constants.dart';

class CardWidget extends StatelessWidget {
  CardWidget({
    super.key,
    required this.title,
    required this.description,
    required this.imgSrc,
    required this.completed,
  });

  final String title;
  final String description;
  final String imgSrc;
  final bool completed;

  final borderRadius = BorderRadius.circular(10);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 5.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        color: completed ? null : Colors.white12,
        child: InkWell(
          borderRadius: borderRadius,
          onTap:
              completed
                  ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SegmentPage(imgSrc: imgSrc,)),
                    );
                  }
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              spacing: 20.0,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3.0),
                  child:
                      completed
                          ? Image.asset(imgSrc, width: 50.0)
                          : Opacity(
                            opacity: 0.75,
                            child: Image.asset(
                              'assets/images/loading_icon.jpg',
                              width: 50.0,
                            ),
                          ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KTextStyle.titleTealText),
                    Text(description, style: KTextStyle.descriptionText),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
