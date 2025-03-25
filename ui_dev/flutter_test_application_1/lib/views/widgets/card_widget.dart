import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';
import 'package:flutter_test_application_1/views/widgets/segment_hero_widget.dart';

import '../../data/constants.dart';

class CardWidget extends StatelessWidget {
  CardWidget({
    super.key,
    required this.title,
    required this.description,
    required this.imgSrc,
    required this.completed,
    this.imageId,
    this.plantId,
  });

  final String title;
  final String description;
  final String imgSrc;
  final bool completed;
  final String? imageId;
  final String? plantId;
  final String uniqueId = UniqueKey().toString();

  final borderRadius = BorderRadius.circular(10);

  @override
  Widget build(BuildContext context) {
    // Use imageId if provided, otherwise use uniqueId
    final id = imageId ?? uniqueId;

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
                      MaterialPageRoute(
                        builder:
                            (context) => SegmentPage(
                              imgSrc: imgSrc,
                              id: id,
                              plantId: plantId,
                            ),
                      ),
                    );
                  }
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              spacing: 20.0,
              children: [
                SizedBox(
                  width: 50.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3.0),
                    child:
                        completed
                            ? SegmentHero(
                              imgSrc:
                                  imgSrc, // Use the actual image URL instead of a static asset
                              id: id,
                            )
                            : Opacity(
                              opacity: 0.75,
                              child: Image.network(
                                imgSrc,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  (loadingProgress
                                                          .expectedTotalBytes ??
                                                      1)
                                              : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/images/loading_icon.jpg',
                                  );
                                },
                              ),
                            ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: KTextStyle.titleTealText),
                        Text(
                          description,
                          style: KTextStyle.descriptionText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
