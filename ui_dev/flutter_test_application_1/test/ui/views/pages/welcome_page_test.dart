import 'dart:async';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';
import 'package:flutter_test_application_1/views/pages/welcome_page.dart';
import 'package:flutter_test_application_1/views/pages/login_page.dart';
import 'package:flutter_test_application_1/views/pages/register_page.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  setUpAll(TestHelpers.setupFirebaseMocks);
  setUp(TestHelpers.auth.reset);
  tearDown(() => LocalGuestService().setLocalGuestMode(false));
  final cloudSupported = LocalGuestService.supportsFirebaseCloudToggle;

  Future<void> pumpWelcome(WidgetTester tester) async {
    await TestHelpers.pumpWithSetup(tester, const WelcomePage());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'Welcome renders local guest action and platform-appropriate cloud options',
    (tester) async {
      await pumpWelcome(tester);
      expect(find.text('PlantDis'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.byType(Lottie), findsOneWidget);
      expect(
        find.text('Login'),
        cloudSupported ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Register'),
        cloudSupported ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  if (cloudSupported) {
    for (final name in ['Login', 'Register']) {
      testWidgets('Welcome navigates to $name', (tester) async {
        await pumpWelcome(tester);
        await tester.ensureVisible(find.text(name));
        await tester.tap(find.text(name));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.byType(name == 'Login' ? LoginPage : RegisterPage),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('Disabling cloud save hides Firebase login actions', (
      tester,
    ) async {
      await pumpWelcome(tester);
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.text('Login'), findsNothing);
      expect(find.text('Register'), findsNothing);
      expect(find.text('Continue as Guest'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'Cloud guest waits for authentication and shows controlled failure',
      (tester) async {
        final pending = Completer<UserCredentialPlatform>();
        var called = false;
        TestHelpers.auth.onAnonymous = () {
          called = true;
          return pending.future;
        };
        await pumpWelcome(tester);
        await tester.ensureVisible(find.text('Continue as Guest'));
        await tester.tap(find.text('Continue as Guest'));
        for (var i = 0; i < 10 && !called; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(called, isTrue);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        pending.completeError(
          FirebaseAuthException(code: 'operation-not-allowed'),
        );
        await tester.pump();
        expect(
          find.textContaining('Anonymous sign-in is not enabled'),
          findsOneWidget,
        );
        expect(find.text('Continue as Guest'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
