import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_test_application_1/views/widgets/image_card.dart';
import 'package:flutter_test_application_1/services/database_service.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';

// Mock Dependencies
class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  late MockDatabaseService mockDbService;
  late Map<String, dynamic> testImageData;

  setUp(() {
    mockDbService = MockDatabaseService();
    // Sample image data (matches ImageCard's expected structure)
    testImageData = {
      'downloadUrl': 'https://test-url.com/image.jpg',
      'uploadTime': DateTime(2024, 5, 20, 14, 30),
      'processingStatus': 'completed',
      'plantType': 'Tomato Plant',
      'id': 'img_001',
    };
    // Mock UIUtils confirmation dialog
    when(UIUtils.showConfirmationDialog(
      context: anyNamed('context'),
      title: anyNamed('title'),
      message: anyNamed('message'),
      confirmText: anyNamed('confirmText'),
      cancelText: anyNamed('cancelText'),
      confirmColor: anyNamed('confirmColor'),
    )).thenAnswer((_) async => true);
  });

  // Helper: Wrap widget with Material context
  Widget wrapWithMaterial({required ImageCard child}) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('ImageCard Display Tests', () {
    testWidgets('Shows all details when showDetails is true', 
        (WidgetTester tester) async {
      final imageCard = ImageCard(
        imageData: testImageData,
        showDetails: true,
      );

      await tester.pumpWidget(wrapWithMaterial(child: imageCard));
      await tester.pumpAndSettle();

      // Verify plant type and formatted date
      expect(find.text('Tomato Plant'), findsOneWidget);
      expect(find.text('Uploaded: 20/5/2024 14:30'), findsOneWidget);
      // Verify status indicator (completed → green)
      final statusContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(ImageCard),
          matching: find.byWidgetPredicate((w) => w is Container && w.decoration?.color != null),
        ),
      );
      expect(statusContainer.decoration?.color, Colors.green.withAlpha(204)); // 0.8 alpha
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('Hides details when showDetails is false', 
        (WidgetTester tester) async {
      final imageCard = ImageCard(
        imageData: testImageData,
        showDetails: false,
      );

      await tester.pumpWidget(wrapWithMaterial(child: imageCard));

      // Verify details are hidden
      expect(find.text('Tomato Plant'), findsNothing);
      expect(find.text('Uploaded: 20/5/2024 14:30'), findsNothing);
    });

    testWidgets('Shows error icon when downloadUrl is null', 
        (WidgetTester tester) async {
      final invalidImageData = testImageData..['downloadUrl'] = null;
      final imageCard = ImageCard(imageData: invalidImageData);

      await tester.pumpWidget(wrapWithMaterial(child: imageCard));

      // Verify error icon (image_not_supported)
      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
      expect(find.byType(Image.network), findsNothing);
    });

    testWidgets('Applies correct status color and text', 
        (WidgetTester tester) async {
      // Test all status types
      final statusCases = [
        {'status': 'pending', 'color': Colors.orange, 'text': 'Pending'},
        {'status': 'processing', 'color': Colors.blue, 'text': 'Processing'},
        {'status': 'failed', 'color': Colors.red, 'text': 'Failed'},
        {'status': 'unknown', 'color': Colors.grey, 'text': 'Unknown'},
      ];

      for (final caseData in statusCases) {
        final testData = testImageData..['processingStatus'] = caseData['status'];
        final imageCard = ImageCard(imageData: testData);

        await tester.pumpWidget(wrapWithMaterial(child: imageCard));
        await tester.pumpAndSettle();

        // Verify status text
        expect(find.text(caseData['text'] as String), findsOneWidget);
        // Verify status color
        final statusContainer = tester.widget<Container>(
          find.descendant(
            of: find.byType(ImageCard),
            matching: find.text(caseData['text'] as String).parent,
          ),
        );
        expect(statusContainer.decoration?.color, 
            (caseData['color'] as Color).withAlpha(204)); // 0.8 alpha
      }
    });
  });

  group('ImageCard Interaction Tests', () {
    testWidgets('Triggers onTap when card is tapped', 
        (WidgetTester tester) async {
      bool tapCalled = false;
      final imageCard = ImageCard(
        imageData: testImageData,
        onTap: (data) => tapCalled = true,
      );

      await tester.pumpWidget(wrapWithMaterial(child: imageCard));
      await tester.tap(find.byType(ImageCard));
      await tester.pumpAndSettle();

      expect(tapCalled, isTrue);
    });

    testWidgets('Triggers onDelete when delete is confirmed', 
        (WidgetTester tester) async {
      bool deleteCalled = false;
      final imageCard = ImageCard(
        imageData: testImageData,
        onDelete: () => deleteCalled = true,
      );

      await tester.pumpWidget(wrapWithMaterial(child: imageCard));
      // Tap delete button (positioned top-left)
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle(); // Wait for confirmation dialog

      // Verify onDelete is called
      expect(deleteCalled, isTrue);
      // Verify database delete is triggered
      verify(mockDbService.deleteImage('img_001')).called(1);
      // Verify deletion dialog is shown
      verify(UIUtils.showDeletionDialog(
        any,
        'Deleting image...\nDeletion will continue in the background.',
        timeoutSeconds: 3,
      )).called(1);
    });

    testWidgets('Does NOT trigger onDelete when delete is canceled', 
        (WidgetTester tester) async {
      // Mock canceled confirmation
      when(UIUtils.showConfirmationDialog(
        context: anyNamed('context'),
        title: anyNamed('title'),
        message: anyNamed('message'),
        confirmText: anyNamed('confirmText'),
        cancelText: anyNamed('cancelText'),
        confirmColor: anyNamed('confirmColor'),
      )).thenAnswer((_) async => false);

      bool deleteCalled = false;
      final imageCard = ImageCard(
        imageData: testImageData,
        onDelete: () => deleteCalled = true,
      );

      await tester.pumpWidget(wrapWithMaterial(child: imageCard));
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      // Verify onDelete is NOT called
      expect(deleteCalled, isFalse);
      verifyNever(mockDbService.deleteImage(any));
    });
  });
}
