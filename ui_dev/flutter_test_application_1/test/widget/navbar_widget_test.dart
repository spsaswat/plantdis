import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/data/notifiers.dart';
import 'package:flutter_test_application_1/views/widgets/navbar_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    selectedPageNotifier.value = 0;
  });

  testWidgets('NavBarWidget switches selected index on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(bottomNavigationBar: NavBarWidget())),
    );

    // Default selected index is 0 (Home)
    expect(selectedPageNotifier.value, 0);

    // Tap Chat (index 1)
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    expect(selectedPageNotifier.value, 1);

    // Tap Profile (index 2)
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    expect(selectedPageNotifier.value, 2);
  });
}
