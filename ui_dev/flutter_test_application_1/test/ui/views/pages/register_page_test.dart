import 'dart:async';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/pages/register_page.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  setUpAll(TestHelpers.setupFirebaseMocks);
  setUp(TestHelpers.auth.reset);
  final register = find.widgetWithText(FilledButton, 'Register');

  testWidgets('Register renders its heading, three fields and submit button', (
    tester,
  ) async {
    await TestHelpers.pumpWithSetup(tester, const RegisterPage());
    expect(find.text('Register'), findsNWidgets(2));
    expect(register, findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Username / Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
  });

  for (final mismatch in [false, true]) {
    testWidgets(
      'Rejects ${mismatch ? "mismatched passwords" : "empty fields"} without registering',
      (tester) async {
        var called = false;
        TestHelpers.auth.onRegister = (_, _) {
          called = true;
          throw StateError('Unexpected registration');
        };
        await TestHelpers.pumpWithSetup(tester, const RegisterPage());
        if (mismatch) {
          await tester.enterText(
            find.byType(TextField).at(0),
            'test@example.com',
          );
          await tester.enterText(find.byType(TextField).at(1), 'password123');
          await tester.enterText(find.byType(TextField).at(2), 'password124');
        }
        await tester.ensureVisible(register);
        await tester.tap(register);
        await tester.pump();
        expect(
          find.text(
            mismatch ? 'Passwords do not match' : 'Please fill in all fields',
          ),
          findsOneWidget,
        );
        expect(called, isFalse);
      },
    );
  }

  testWidgets('Registration waits for auth and restores button after failure', (
    tester,
  ) async {
    final pending = Completer<UserCredentialPlatform>();
    TestHelpers.auth.onRegister = (email, password) {
      expect(email, 'test@example.com');
      expect(password, 'password123');
      return pending.future;
    };
    await TestHelpers.pumpWithSetup(tester, const RegisterPage());
    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.ensureVisible(register);
    await tester.tap(register);
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(FirebaseAuthException(code: 'email-already-in-use'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(register, findsOneWidget);
    expect(tester.widget<FilledButton>(register).onPressed, isNotNull);
    expect(
      find.textContaining('The email address is already in use.'),
      findsWidgets,
    );
  });
}
