import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';

import '../widgets/hero_widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroWidget(title: "PlantDis"),
            SizedBox(height: 10.0),
            Text("Results", style: TextStyle(color: Colors.blueGrey)),
            Divider(),
            ...List.generate(2, (index) {
              return CardWidget(
                title: "Basic Layout $index",
                description: "Basic Desc",
                imgSrc: 'assets/images/segmentation.png',
                completed: true,
              );
            }),
            Text("Processing", style: TextStyle(color: Colors.blueGrey)),
            Divider(),
            ...List.generate(3, (index) {
              return CardWidget(
                title: "Basic Layout $index",
                description: "Basic Desc",
                imgSrc: 'assets/images/loading_icon.jpg',
                completed: false,
              );
            }),
          ],
        ),
      ),
    );
  }
}
