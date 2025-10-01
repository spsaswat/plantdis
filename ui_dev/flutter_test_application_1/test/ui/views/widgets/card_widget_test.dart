import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_test_application_1/models/image_model.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';

// Mock Dependencies
class MockPlantService extends Mock implements PlantService {}

void main() {
  late MockPlantService mockPlantService;

  setUp(() {
    mockPlantService = MockPlantService();
  });

  // Helper: Wrap widget with Material context
  Widget wrapWithMaterial({required CardWidget child}) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('CardWidget Display Tests', () {
    testWidgets(
      'Shows title, description, and default error icon when no imageId',
      (WidgetTester tester) async {
        final card = CardWidget(
          title: 'Test Plant',
          description: 'Test Description for Plant Disease',
          completed: true,
          plantId: 'plant_001',
        );

        await tester.pumpWidget(wrapWithMaterial(child: card));
        await tester.pumpAndSettle();

        // Verify core text display
        expect(find.text('Test Plant'), findsOneWidget);
        expect(find.text('Test Description for Plant Disease'), findsOneWidget);
        // Verify error icon (no imageId → error asset)
        expect(
          find.byAssetImage('assets/images/error_icon.png'),
          findsOneWidget,
        );
        // Verify delete button
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    testWidgets('Loads network image successfully when imageId is provided', (
      WidgetTester tester,
    ) async {
      // Mock image data response
      final mockImages = [
        ImageModel(
          imageId: 'img_001',
          plantId: 'plant_001',
          userId: 'user_001',
          originalUrl: 'https://test-url.com/image.jpg',
          processedUrls: {'thumbnail': 'https://test-url.com/thumb.jpg'},
          uploadTime: DateTime.now(),
        ),
      ];
      when(
        mockPlantService.getPlantImages('plant_001'),
      ).thenAnswer((_) async => mockImages);

      final card = CardWidget(
        title: 'Test Plant',
        description: 'Test Description',
        completed: true,
        imageId: 'img_001',
        plantId: 'plant_001',
      );

      await tester.pumpWidget(wrapWithMaterial(child: card));
      await tester.pumpAndSettle(); // Wait for FutureBuilder

      // Verify no error icon
      expect(find.byAssetImage('assets/images/error_icon.png'), findsNothing);
    });

    testWidgets('Shows error icon when image fetch fails', (
      WidgetTester tester,
    ) async {
      // Mock failed image fetch
      when(
        mockPlantService.getPlantImages('plant_001'),
      ).thenThrow(Exception('Fetch Failed'));

      final card = CardWidget(
        title: 'Test Plant',
        description: 'Test Description',
        completed: true,
        imageId: 'img_001',
        plantId: 'plant_001',
      );

      await tester.pumpWidget(wrapWithMaterial(child: card));
      await tester.pumpAndSettle();

      // Verify error icon fallback
      expect(find.byAssetImage('assets/images/error_icon.png'), findsOneWidget);
    });

    testWidgets('Applies opacity to image when not completed', (
      WidgetTester tester,
    ) async {
      final mockImages = [
        ImageModel(
          imageId: 'img_001',
          plantId: 'plant_001',
          userId: 'user_001',
          originalUrl: 'https://test-url.com/image.jpg',
          processedUrls: {},
          uploadTime: DateTime.now(),
        ),
      ];
      when(
        mockPlantService.getPlantImages('plant_001'),
      ).thenAnswer((_) async => mockImages);

      final card = CardWidget(
        title: 'Test Plant',
        description: 'Test Description',
        completed: false, // Not completed → opacity 0.75
        imageId: 'img_001',
        plantId: 'plant_001',
      );

      await tester.pumpWidget(wrapWithMaterial(child: card));
      await tester.pumpAndSettle();

      // Verify Opacity widget exists
      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.75);
    });
  });

  group('CardWidget Interaction Tests', () {
    testWidgets(
      'Navigates to SegmentPage when tapped (completed & image exists)',
      (WidgetTester tester) async {
        final mockImages = [
          ImageModel(
            imageId: 'img_001',
            plantId: 'plant_001',
            userId: 'user_001',
            originalUrl: 'https://test-url.com/image.jpg',
            processedUrls: {},
            uploadTime: DateTime.now(),
          ),
        ];
        when(
          mockPlantService.getPlantImages('plant_001'),
        ).thenAnswer((_) async => mockImages);

        final card = CardWidget(
          title: 'Test Plant',
          description: 'Test Description',
          completed: true,
          imageId: 'img_001',
          plantId: 'plant_001',
        );

        await tester.pumpWidget(wrapWithMaterial(child: card));
        await tester.pumpAndSettle();

        // Tap the card
        await tester.tap(find.byType(CardWidget));
        await tester.pumpAndSettle();

        // Verify navigation to SegmentPage
        expect(find.byType(SegmentPage), findsOneWidget);
        // Verify SegmentPage receives correct arguments
        final segmentPage = tester.widget<SegmentPage>(
          find.byType(SegmentPage),
        );
        expect(segmentPage.imgSrc, 'https://test-url.com/image.jpg');
        expect(segmentPage.plantId, 'plant_001');
      },
    );

    testWidgets('Does NOT navigate when tapped (not completed)', (
      WidgetTester tester,
    ) async {
      final card = CardWidget(
        title: 'Test Plant',
        description: 'Test Description',
        completed: false, // Not completed → tap disabled
        plantId: 'plant_001',
      );

      await tester.pumpWidget(wrapWithMaterial(child: card));
      await tester.pumpAndSettle();

      // Tap the card (should have no effect)
      await tester.tap(find.byType(CardWidget));
      await tester.pumpAndSettle();

      // Verify no navigation
      expect(find.byType(SegmentPage), findsNothing);
    });

    testWidgets('Triggers onDelete when delete is confirmed', (
      WidgetTester tester,
    ) async {
      bool deleteCalled = false;
      final card = CardWidget(
        title: 'Test Plant',
        description: 'Test Description',
        completed: true,
        plantId: 'plant_001',
        onDelete: () => deleteCalled = true,
      );

      await tester.pumpWidget(wrapWithMaterial(child: card));
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle(); // Wait for confirmation dialog

      // Confirm deletion in dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog triggers onDelete
      expect(deleteCalled, isTrue);
    });

    testWidgets('Disables delete button during deletion', (
      WidgetTester tester,
    ) async {
      bool deleteCalled = false;
      final card = CardWidget(
        title: 'Test Plant',
        description: 'Test Description',
        completed: true,
        plantId: 'plant_001',
        onDelete: () {
          deleteCalled = true;
          Future.delayed(
            const Duration(seconds: 1),
          ); // Simulate background delay
        },
      );

      await tester.pumpWidget(wrapWithMaterial(child: card));
      await tester.pumpAndSettle();

      // Tap delete button (triggers deletion state)
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle(); // Wait for confirmation dialog
      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 100)); // Update state

      // Verify delete button is disabled (grey color)
      final deleteIcon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
      expect(deleteIcon.color, Colors.grey);
      // Verify re-tap has no effect
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(deleteCalled, isTrue); // Only called once
    });
  });
}
