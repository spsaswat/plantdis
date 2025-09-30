import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test_application_1/data/notifiers.dart';
import 'package:flutter_test_application_1/views/pages/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    isDarkModeNotifier.value = true;
  });

  testWidgets('SettingsPage toggles dark mode switch', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage(title: 'Settings')),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    final Switch s = tester.widget(switchFinder);
    final initial = s.value;
    await tester.tap(switchFinder);
    await tester.pump();
    final Switch s2 = tester.widget(switchFinder);
    expect(s2.value, isNot(initial));
  });
}
