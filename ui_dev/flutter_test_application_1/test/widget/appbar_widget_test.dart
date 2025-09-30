import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppbarWidget renders title and has preferred size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(appBar: AppbarWidget())),
    );

    expect(find.text('Plant Disease Detector'), findsOneWidget);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isTrue);

    const appbar = AppbarWidget();
    expect(appbar.preferredSize.height, kToolbarHeight);
  });
}
