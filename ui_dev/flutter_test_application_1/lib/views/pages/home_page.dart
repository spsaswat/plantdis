import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/services/database_service.dart';
import 'package:flutter_test_application_1/views/pages/processing_page.dart';
import 'package:flutter_test_application_1/views/pages/results_page.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';

import '../widgets/hero_widget.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService database = DatabaseService();

  final List<CardWidget> resultsList = List.generate(4, (index) {
    return CardWidget(
      title: "Basic Layout ${index + 1}",
      description: "Basic Desc",
      imgSrc: 'assets/images/segmentation.png',
      completed: true,
    );
  });

  late List<CardWidget> processingList = // List.empty(growable: true);
  List.generate(7, (index) {
    return CardWidget(
      title: "Basic Layout ${index + 1}",
      description: "Basic Desc",
      imgSrc: 'assets/images/loading_icon.jpg',
      completed: false,
    );
  });

  late StreamController processingListController;

  @override
  void initState() {
    super.initState();
    processingListController = StreamController();
    getImages();
  }

  @override
  void dispose() {
    super.dispose();
    processingListController.close();
  }

  void getImages() async {
    var imageList = await database.getImages();

    for (int i = 0; i < imageList.length; i++) {
      processingListController.sink.add(i);
      processingList.add(
        CardWidget(
          title: "Image ${i + 1}",
          description: "Processing",
          imgSrc: imageList[i].fullPath,
          completed: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FractionallySizedBox(
                widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    HeroWidget(title: "PlantDis"),
                    SizedBox(height: 10.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Results (${resultsList.length})"),
                        TextButton(
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          ResultsPage(cardList: resultsList),
                                ),
                              ),
                          child: Text("View all"),
                        ),
                      ],
                    ),
                    Divider(),
                    ...resultsList.sublist(0, 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Processing (${processingList.length})"),
                        TextButton(
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ProcessingPage(
                                        cardList: processingList,
                                      ),
                                ),
                              ),
                          child: Text("View all"),
                        ),
                      ],
                    ),
                    Divider(),
                    ...processingList.sublist(0, 2),
                    // StreamBuilder(
                    //   stream: processingListController.stream,
                    //   builder: (context, snapshot) {
                    //     if (snapshot.connectionState ==
                    //         ConnectionState.waiting) {
                    //       return CircularProgressIndicator.adaptive();
                    //     } else {
                    //       return ListView(
                    //         children: [
                    //           ...(processingList.length > 2
                    //               ? processingList.sublist(0, 2)
                    //               : processingList),
                    //         ],
                    //       );
                    //     }
                    //   },
                    // ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
