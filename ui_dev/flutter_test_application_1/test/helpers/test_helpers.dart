// test/helpers/test_helpers.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Provides convenience helpers for login/register page tests.
class TestHelpers {
  /// Initializes test bindings for widget/Firebase-related tests.
  static Future<void> setupFirebaseMocks() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  /// Wraps the widget under test with MaterialApp.
  static Widget createTestApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  /// Pumps the widget into the test environment and settles one frame.
  static Future<void> pumpWithSetup(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(createTestApp(child));
    await tester.pump();
  }
}
