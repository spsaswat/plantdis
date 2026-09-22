import 'dart:async';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/pages/login_page.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  setUpAll(TestHelpers.setupFirebaseMocks);
  setUp(TestHelpers.auth.reset);

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pump();
  }

  testWidgets('Login renders fields, actions and password obscuring', (
    tester,
  ) async {
    await TestHelpers.pumpWithSetup(tester, const LoginPage());
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Username / Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).obscureText,
      isFalse,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isTrue,
    );
  });

  for (final missing in ['both', 'email', 'password']) {
    testWidgets('Rejects missing $missing before contacting authentication', (
      tester,
    ) async {
      var called = false;
      TestHelpers.auth.onSignIn = (_, _) {
        called = true;
        throw StateError('Authentication must not run for invalid input');
      };
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      if (missing == 'email') {
        await tester.enterText(find.byType(TextField).at(1), 'password123');
      } else if (missing == 'password') {
        await tester.enterText(
          find.byType(TextField).at(0),
          'test@example.com',
        );
      }
      await tester.ensureVisible(find.text('Get Started'));
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      expect(find.text('Please enter both email and password'), findsOneWidget);
      expect(called, isFalse);
    });
  }

  for (final field in [0, 1]) {
    testWidgets('Editing field $field immediately clears the previous error', (
      tester,
    ) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      await tester.ensureVisible(find.text('Get Started'));
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      expect(find.text('Please enter both email and password'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(field), 'updated');
      await tester.pump();
      expect(find.text('Please enter both email and password'), findsNothing);
    });
  }

  testWidgets(
    'Pending login disables button; controlled failure restores form and preserves input',
    (tester) async {
      final pending = Completer<UserCredentialPlatform>();
      final started = Completer<void>();
      TestHelpers.auth.onSignIn = (email, password) {
        expect(email, 'test@example.com');
        expect(password, 'password123');
        started.complete();
        return pending.future;
      };
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      await submit(tester);
      // The service first looks up the IP; the test binding blocks that HTTP call.
      for (var i = 0; i < 10 && !started.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(started.isCompleted, isTrue);
      final button = find.byType(FilledButton);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(
        find.descendant(
          of: button,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      pending.completeError(FirebaseAuthException(code: 'wrong-password'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Get Started'), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(find.text('Exception: Wrong password.'), findsOneWidget);
      expect(
        find.text('Login Failed: Exception: Wrong password.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('password123'), findsOneWidget);
    },
  );

  for (final width in [400.0, 1200.0]) {
    testWidgets('Login layout at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(
        tester
            .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
            .widthFactor,
        width > 600 ? 0.5 : 1.0,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Disposing page disposes both text controllers', (tester) async {
    await TestHelpers.pumpWithSetup(tester, const LoginPage());
    final controllers =
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((field) => field.controller!)
            .toList();
    await tester.pumpWidget(const SizedBox.shrink());
    for (final controller in controllers) {
      expect(() => controller.addListener(() {}), throwsFlutterError);
    }
  });
}
