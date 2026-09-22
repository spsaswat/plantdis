import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test_application_1/main.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:flutter_test_application_1/views/pages/welcome_page.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'App opens welcome screen with saved ${dark ? "dark" : "light"} theme',
      (tester) async {
        SharedPreferences.setMockInitialValues({KKeys.themeModeKey: dark});
        await tester.pumpWidget(const MyApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(WelcomePage), findsOneWidget);
        expect(find.text('PlantDis'), findsOneWidget);
        expect(find.text('Continue as Guest'), findsOneWidget);
        final context = tester.element(find.byType(WelcomePage));
        expect(
          Theme.of(context).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
