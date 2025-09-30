import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/widgets/navbar_widget.dart';
import 'package:flutter_test_application_1/data/notifiers.dart';

void main() {
  testWidgets('NavBarWidget 渲染测试', (WidgetTester tester) async {
    // Initialize the test environment
    await tester.pumpWidget(const MaterialApp(home: Scaffold(bottomNavigationBar: NavBarWidget())));

    // Verify the number of navigation items
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Verify the initial selection
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(selectedPageNotifier.value, 0);

    // Testing navigation switching
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(selectedPageNotifier.value, 1);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(selectedPageNotifier.value, 2);
  });
}
