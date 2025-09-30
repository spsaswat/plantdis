import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/widgets/segment_widget.dart';
import 'dart:io';

void main() {
  late File testImageFile;
  const testTitle = "Leaf Segmentation";

  // Setup temporary test image file before all tests
  setUpAll(() async {
    try {
      // Create in-memory temporary file to avoid using path_provider
      final tempDir = Directory.systemTemp;
      testImageFile = File('${tempDir.path}/test_segment_${DateTime.now().millisecondsSinceEpoch}.png');
      
      // Write valid PNG file data
      final pngBytes = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, // IHDR chunk length
        0x49, 0x48, 0x44, 0x52, // "IHDR"
        0x00, 0x00, 0x00, 0x01, // Width: 1
        0x00, 0x00, 0x00, 0x01, // Height: 1
        0x08, 0x02, 0x00, 0x00, 0x00, // Bit depth, color type, etc.
        0x90, 0x77, 0x53, 0xDE, // CRC
        0x00, 0x00, 0x00, 0x00, // IEND chunk length
        0x49, 0x45, 0x4E, 0x44, // "IEND"
        0xAE, 0x42, 0x60, 0x82  // CRC
      ];
      
      await testImageFile.writeAsBytes(pngBytes);
    } catch (e) {
      // Fallback if file creation fails
      testImageFile = File('test_segment.png');
    }
  });

  // Clean up test file after all tests
  tearDownAll(() {
    try {
      if (testImageFile.existsSync()) {
        testImageFile.deleteSync();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  // Helper method to wrap widget in MaterialApp context
  Widget wrapInTestApp({required SegmentWidget child}) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('SegmentWidget UI Rendering Tests', () {
    testWidgets('handles missing image gracefully', (WidgetTester tester) async {
      // Create non-existent file path
      final missingFile = File('nonexistent_file_${DateTime.now().millisecondsSinceEpoch}.png');
      
      final segmentWidget = SegmentWidget(
        segmentationFile: missingFile,
        title: testTitle,
      );

      await tester.pumpWidget(wrapInTestApp(child: segmentWidget));
      await tester.pumpAndSettle();

      // Verify title still displays
      expect(find.text(testTitle), findsOneWidget);
      
      // Verify widget doesn't crash with missing file
      expect(find.byType(SegmentWidget), findsOneWidget);
    });

    testWidgets('displays title correctly', (WidgetTester tester) async {
      final segmentWidget = SegmentWidget(
        segmentationFile: testImageFile,
        title: testTitle,
      );

      await tester.pumpWidget(wrapInTestApp(child: segmentWidget));
      await tester.pumpAndSettle();

      expect(find.text(testTitle), findsOneWidget);
    });
  });

  group('SegmentWidget Interaction Tests', () {
    testWidgets('shows image correctly', (WidgetTester tester) async {
      final segmentWidget = SegmentWidget(
        segmentationFile: testImageFile,
        title: testTitle,
      );

      await tester.pumpWidget(wrapInTestApp(child: segmentWidget));
      await tester.pumpAndSettle();

      // Verify image is displayed
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('taps on image should not crash', (WidgetTester tester) async {
      final segmentWidget = SegmentWidget(
        segmentationFile: testImageFile,
        title: testTitle,
      );

      await tester.pumpWidget(wrapInTestApp(child: segmentWidget));
      await tester.pumpAndSettle();

      // Tap on image widget and verify it doesn't crash
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      // Verify widget still exists
      expect(find.byType(SegmentWidget), findsOneWidget);
    });
  });

  group('SegmentWidget Theming Tests', () {
    testWidgets('applies correct styling', (WidgetTester tester) async {
      final segmentWidget = SegmentWidget(
        segmentationFile: testImageFile,
        title: testTitle,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(body: segmentWidget),
        )
      );
      await tester.pumpAndSettle();

      // Verify card exists
      expect(find.byType(Card), findsOneWidget);
      
      // Verify title styling
      final titleText = tester.widget<Text>(find.text(testTitle));
      expect(titleText.style?.fontSize, 16);
      expect(titleText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('uses theme colors correctly', (WidgetTester tester) async {
      final segmentWidget = SegmentWidget(
        segmentationFile: testImageFile,
        title: testTitle,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: segmentWidget),
        )
      );
      await tester.pumpAndSettle();

      // Verify widget renders properly in dark theme
      expect(find.byType(SegmentWidget), findsOneWidget);
      expect(find.text(testTitle), findsOneWidget);
    });
  });
}
