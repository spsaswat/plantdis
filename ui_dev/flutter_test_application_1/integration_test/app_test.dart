// integration_test/app_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ⚠️ Update the import according to your actual entry point (assuming lib/main.dart exports MyApp)
import 'package:flutter_test_application_1/main.dart' show MyApp;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App smoke & basic flow', () {
    testWidgets('Boots, shows home, optional nav & input, and back', (tester) async {
      // 1) Launch the application
      await tester.pumpWidget(const MyApp());

      // 2) Wait for stabilization (allow sufficient time for animations/initial screen loading)
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 3) Basic assertions (choose one or keep both for enhanced robustness)
      // 3.1 Check by title/brand text (replace with actual text from your home screen)
      expect(find.textContaining('PlantDis'), findsWidgets);

      // 3.2 If your home Scaffold has a Key, use:
      // expect(find.byKey(const ValueKey('home-scaffold')), findsOneWidget);

      // 4) Optional: Take screenshot of home screen (requires device/emulator support)
      await binding.takeScreenshot('01_home_booted');

      // 5) If there's a "Start Scan" FAB or button, attempt to tap and navigate to next page
      //    Replace ValueKey with actual keys from your project
      final startScanKey = find.byKey(const ValueKey('fab-start-scan'));
      final startScanText = find.textContaining('Start Scan');

      if (startScanKey.evaluate().isNotEmpty || startScanText.evaluate().isNotEmpty) {
        final target = startScanKey.evaluate().isNotEmpty ? startScanKey : startScanText;
        await tester.tap(target);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Assert that we've navigated to the next page (add a stable identifier to target page, e.g., Key or title)
        final scanPageMarker = find.byKey(const ValueKey('scan-page'));
        final scanTitleText = find.textContaining('Scan');

        expect(
          scanPageMarker.evaluate().isNotEmpty || scanTitleText.evaluate().isNotEmpty,
          true,
          reason: 'Should navigate to scan page or display scan-related title',
        );

        await binding.takeScreenshot('02_after_enter_scan_page');

        // 6) If there's an input field, attempt to enter text (avoid actual camera/gallery operations)
        final inputFieldByKey = find.byKey(const ValueKey('scan-input'));
        final genericTextField = find.byType(TextField);
        if (inputFieldByKey.evaluate().isNotEmpty || genericTextField.evaluate().isNotEmpty) {
          final textField = inputFieldByKey.evaluate().isNotEmpty ? inputFieldByKey : genericTextField.first;
          await tester.tap(textField);
          await tester.enterText(textField, 'test_leaf.jpg');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(find.text('test_leaf.jpg'), findsOneWidget);
        }

        // 7) Return to home screen (if back button/navigation exists)
        final backButton = find.byTooltip('Back').hitTestable();
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle(const Duration(seconds: 3));
        } else {
          // No AppBar back button: attempt system back (may not work on some platforms, ignore failures)
          await tester.pageBack();
          await tester.pumpAndSettle(const Duration(seconds: 3));
        }

        // 8) Confirm return to home screen
        expect(find.textContaining('PlantDis'), findsWidgets);
        await binding.takeScreenshot('03_back_to_home');
      }
    });
  });
}
