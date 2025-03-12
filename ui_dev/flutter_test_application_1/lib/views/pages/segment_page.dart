import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/segment_hero_widget.dart';
import 'package:lorem_ipsum/lorem_ipsum.dart';

class SegmentPage extends StatelessWidget {
  SegmentPage({super.key, required this.imgSrc, required this.id});

  final String imgSrc;
  final String id;
  final String fillerText = loremIpsum(paragraphs: 3, initWithLorem: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppbarWidget(),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FractionallySizedBox(
                  widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                  child: Column(
                    spacing: 10.0,
                    children: [
                      SegmentHero(imgSrc: imgSrc, id: id),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 5.0,
                              children: [
                                Center(
                                  child: Text(
                                    "Analysis",
                                    style: KTextStyle.titleTealText,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "Plant Name: ",
                                      style: KTextStyle.termTealText,
                                    ),
                                    Text(
                                      "Dummy Plant Name",
                                      style: KTextStyle.descriptionText,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "Disease Type: ",
                                      style: KTextStyle.termTealText,
                                    ),
                                    Text(
                                      "Dummy Disease Type",
                                      style: KTextStyle.descriptionText,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              spacing: 5.0,
                              children: [
                                Text(
                                  "Information",
                                  style: KTextStyle.titleTealText,
                                ),
                                Text(
                                  fillerText,
                                  style: KTextStyle.descriptionText,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
