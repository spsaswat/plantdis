import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';

void main() {
  testWidgets('AppbarWidget displays correct title and style', (tester) async {
    // create widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: const AppbarWidget(),
        ),
      ),
    );

    // verify the title
    expect(find.text('Plant Disease Detector'), findsOneWidget);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, true);

    // verify background color
    expect(appBar.backgroundColor, Colors.green);

    // verify preferredSize
    expect(const AppbarWidget().preferredSize, equals(const Size.fromHeight(kToolbarHeight)));
  });
}
