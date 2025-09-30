import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_test_application_1/views/widgets/drawer_widget.dart';
import 'package:flutter_test_application_1/views/pages/settings_page.dart';
import 'package:flutter_test_application_1/utils/web_utils.dart';
import 'package:flutter_test_application_1/data/notifiers.dart';

// Mock Dependencies
class MockWebUtils extends Mock implements WebUtils {}

void main() {

  setUp(() {
    // Reset notifier state before each test
    selectedPageNotifier.value = 0;
  });

  // Helper: Wrap Scaffold with DrawerWidget
  Widget wrapWithScaffold() {
    return MaterialApp(
      home: Scaffold(
        drawer: const DrawerWidget(),
        appBar: AppBar(title: const Text('Test')),
      ),
    );
  }

  group('DrawerWidget Display Tests', () {
    testWidgets('Shows all menu items and banner', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithScaffold());
      // Open drawer
      await tester.tap(find.byType(DrawerButton));
      await tester.pumpAndSettle();

      // Verify banner (image asset)
      expect(
        find.byWidgetPredicate(
          (widget) => 
          widget is Image && 
          widget.image is AssetImage && 
          (widget.image as AssetImage).assetName == 'assets/images/appn_banner.png',
        ),
      findsOneWidget,
      );
      // Verify menu items
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('About Us'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
      // Verify icons
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.logout_outlined), findsOneWidget);
    });
  });

  group('DrawerWidget Interaction Tests', () {
    testWidgets('Navigates to SettingsPage when "Settings" is tapped', 
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithScaffold());
      await tester.tap(find.byType(DrawerButton));
      await tester.pumpAndSettle();

      // Tap Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify navigation to SettingsPage
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget); // Page title
    });
  });
}
