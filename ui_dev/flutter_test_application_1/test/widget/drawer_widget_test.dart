import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/views/widgets/drawer_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DrawerWidget shows entries and can tap Settings/About/Logout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(drawer: DrawerWidget(), body: SizedBox()),
      ),
    );

    // Open drawer
    ScaffoldState state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // Tap items by tapping the entire ListTile to avoid hit test warnings
    await tester.tap(find.widgetWithText(ListTile, 'Settings'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'About Us'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'Logout'));
    await tester.pump();
  });
}
