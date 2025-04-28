import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';
import 'package:flutter_test_application_1/views/widgets/hero_widget.dart';

class ProcessingPage extends StatelessWidget {
  const ProcessingPage({super.key, required this.cardList});

  final List<CardWidget> cardList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppbarWidget(),
      body: Center(
        heightFactor: 1,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FractionallySizedBox(
                  widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                  child: Column(
                    children: [
                      HeroWidget(title: "Processing"),
                      SizedBox(height: 10.0),
                      if (cardList.isEmpty)
                        Text(
                          "No results available.",
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ...cardList,
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
