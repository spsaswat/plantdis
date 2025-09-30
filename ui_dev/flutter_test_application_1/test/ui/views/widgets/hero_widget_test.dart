import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/widgets/hero_widget.dart';
import 'package:flutter_test_application_1/data/notifiers.dart';

void main() {
  // Helper: Wrap widget (Hero requires parent context for animation)
  Widget wrapWithMaterial({required String title}) {
    return MaterialApp(
      home: Scaffold(
        body: HeroWidget(title: title),
      ),
    );
  }

  group('HeroWidget Tests', () {
    setUp(() {
      // Reset dark mode state before each test
      isDarkModeNotifier.value = false;
    });

    testWidgets('Shows correct title and Hero tag', (WidgetTester tester) async {
      const testTitle = 'TEST HERO';
      await tester.pumpWidget(wrapWithMaterial(title: testTitle));

      // Verify Hero tag
      final heroWidget = tester.widget<Hero>(find.byType(Hero));
      expect(heroWidget.tag, 'hero1');

      // Verify title text
      expect(find.text(testTitle), findsOneWidget);
    });

    testWidgets('Applies dark mode styling when enabled', (WidgetTester tester) async {
      const testTitle = 'DARK MODE';
      await tester.pumpWidget(wrapWithMaterial(title: testTitle));

      // Enable dark mode
      isDarkModeNotifier.value = true;
      await tester.pumpAndSettle(); // Rebuild with new notifier value

      // Verify text color (dark mode → white70)
      final textWidget = tester.widget<Text>(find.text(testTitle));
      expect(textWidget.style?.color, Colors.white70);

      // Verify image blend mode (dark mode → exclusion)
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.colorBlendMode, BlendMode.exclusion);
    });

    testWidgets('Applies light mode styling when disabled', (WidgetTester tester) async {
      const testTitle = 'LIGHT MODE';
      await tester.pumpWidget(wrapWithMaterial(title: testTitle));

      // Ensure light mode is active
      isDarkModeNotifier.value = false;
      await tester.pumpAndSettle();

      // Verify text color (light mode → black87)
      final textWidget = tester.widget<Text>(find.text(testTitle));
      expect(textWidget.style?.color, Colors.black87);

      // Verify image blend mode (light mode → softLight)
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.colorBlendMode, BlendMode.softLight);
    });

    testWidgets('Maintains aspect ratio (1920/1080)', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithMaterial(title: 'ASPECT TEST'));

      // Verify AspectRatio widget
      final aspectWidget = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectWidget.aspectRatio, 1920 / 1080);
    });
  });
}
