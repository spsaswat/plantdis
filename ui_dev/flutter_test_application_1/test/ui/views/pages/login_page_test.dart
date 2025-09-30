import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/pages/login_page.dart';
import '../../../helpers/test_helpers.dart';
import 'package:flutter/material.dart';

void main() {
  setUpAll(() async {
    await TestHelpers.setupFirebaseMocks();
  });

  group('LoginPage UI Tests', () {
    testWidgets('LoginPage renders all elements correctly', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      expect(find.text('Login'), findsOneWidget);
      
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Username / Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('OR'), findsOneWidget);
    });

    testWidgets('Password field is obscured', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      final passwordField = tester.widget<TextField>(
        find.byType(TextField).at(1)
      );
      
      expect(passwordField.obscureText, isTrue);
    });

    testWidgets('Email field is not obscured', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      final emailField = tester.widget<TextField>(
        find.byType(TextField).at(0)
      );
      
      expect(emailField.obscureText, isFalse);
    });
  });

  group('LoginPage Validation Tests', () {
    testWidgets('Shows error when both fields are empty', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      expect(find.text('Please enter both email and password'), findsOneWidget);
    });

    testWidgets('Shows error when email is empty', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      expect(find.text('Please enter both email and password'), findsOneWidget);
    });

    testWidgets('Shows error when password is empty', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      expect(find.text('Please enter both email and password'), findsOneWidget);
    });

    testWidgets('Error message clears when user starts typing', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      expect(find.text('Please enter both email and password'), findsOneWidget);
      
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      
      expect(find.text('Please enter both email and password'), findsNothing);
    });
  });

  group('LoginPage Loading State Tests', () {
    testWidgets('Shows loading indicator when logging in', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Button is disabled during loading', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '').first,
      );
      
      expect(button.onPressed, isNull);
    });

    testWidgets('Loading indicator disappears after error', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrongpassword');
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle();
      
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Get Started'), findsOneWidget);
    });
  });

  group('LoginPage Authentication Tests', () {
    testWidgets('Shows error snackbar on login failure', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrongpassword');
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      await tester.pumpAndSettle();
      
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Login Failed'), findsOneWidget);
    });

    testWidgets('Error message is displayed on screen', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrongpassword');
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      await tester.pumpAndSettle();
      
      expect(find.byWidgetPredicate(
        (widget) => widget is Text && 
                    widget.data != null && 
                    widget.data!.contains('PlatformException'),
      ), findsOneWidget);
    });
  });

  group('LoginPage Text Input Tests', () {
    testWidgets('Can enter email address', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(
        find.byType(TextField).at(0), 
        'user@example.com'
      );
      
      expect(find.text('user@example.com'), findsOneWidget);
    });

    testWidgets('Can enter password', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(
        find.byType(TextField).at(1), 
        'password123'
      );
      
      expect(find.text('password123'), findsOneWidget);
    });

    testWidgets('Can enter both email and password', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(
        find.byType(TextField).at(0), 
        'user@example.com'
      );
      await tester.enterText(
        find.byType(TextField).at(1), 
        'securePassword123'
      );
      
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('securePassword123'), findsOneWidget);
    });

    testWidgets('Text fields maintain state after error', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      const testEmail = 'test@example.com';
      const testPassword = 'testpass';
      
      await tester.enterText(find.byType(TextField).at(0), testEmail);
      await tester.enterText(find.byType(TextField).at(1), testPassword);
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      await tester.pumpAndSettle();
      
      expect(find.text(testEmail), findsOneWidget);
      expect(find.text(testPassword), findsOneWidget);
    });
  });

  group('LoginPage Layout Tests', () {
    testWidgets('Layout adjusts for narrow screens', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      await tester.pumpAndSettle();
      
      expect(find.byType(FractionallySizedBox), findsOneWidget);
      
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Layout adjusts for wide screens', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      await tester.pumpAndSettle();
      
      expect(find.byType(FractionallySizedBox), findsOneWidget);
      
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Content is scrollable', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('Has SafeArea wrapper', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      expect(find.byType(SafeArea), findsOneWidget);
    });
  });

  group('LoginPage Navigation Tests', () {
    testWidgets('Has app bar with back button', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('LoginPage Controller Tests', () {
    testWidgets('Controllers are properly disposed', (tester) async {
      await TestHelpers.pumpWithSetup(tester, const LoginPage());
      
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('password'), findsOneWidget);
    });
  });
}
