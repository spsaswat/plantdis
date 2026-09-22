import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/models/image_model.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';
import '../../../helpers/test_helpers.dart';
import '../../../helpers/card_test_helpers.dart';

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

void main() {
  final store = CardTestFirestore();
  setUpAll(() async {
    await TestHelpers.setupFirebaseMocks();
    FirebaseFirestorePlatform.instance = store;
  });
  setUp(() {
    store.reset();
    TestHelpers.auth.reset();
    TestHelpers.auth.user = CardTestUser(TestHelpers.auth);
    LocalGuestService().setLocalGuestMode(false);
  });

  Map<String, dynamic> imageData() =>
      ImageModel(
        imageId: 'img_001',
        plantId: 'plant_001',
        userId: 'test-user',
        originalUrl: 'https://test.invalid/image.png',
        processedUrls: {},
        uploadTime: DateTime(2025),
      ).toMap();

  Future<void> pumpCard(
    WidgetTester tester, {
    bool completed = true,
    String? imageId,
    VoidCallback? onDelete,
    _Routes? routes,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [if (routes != null) routes],
        home: Scaffold(
          body: CardWidget(
            title: 'Test Plant',
            description: 'Test description',
            completed: completed,
            plantId: 'plant_001',
            imageId: imageId,
            onDelete: onDelete,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
  }

  testWidgets('Missing image shows fallback icon and plant text', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.text('Test Plant'), findsOneWidget);
    expect(find.text('Test description'), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(store.queried, isEmpty);
  });

  testWidgets(
    'Fetched image URL is displayed and pending card dims thumbnail',
    (tester) async {
      store.images = [imageData()];
      await HttpOverrides.runZoned(() async {
        await pumpCard(tester, imageId: 'img_001', completed: false);
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump();
        expect(store.queried, ['images']);
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          (image.image as NetworkImage).url,
          'https://test.invalid/image.png',
        );
        final opacity = tester.widget<Opacity>(
          find
              .ancestor(of: find.byType(Image), matching: find.byType(Opacity))
              .first,
        );
        expect(opacity.opacity, 0.75);
        await tester.pumpWidget(const SizedBox.shrink());
      }, createHttpClient: ImageHttpOverrides().createHttpClient);
    },
  );

  for (final queryFails in [false, true]) {
    testWidgets(
      'Shows fallback when image ${queryFails ? "lookup fails" : "is missing"}',
      (tester) async {
        if (queryFails) {
          store.queryError = StateError('simulated lookup failure');
        }
        await pumpCard(tester, imageId: 'img_001');
        expect(store.queried, ['images']);
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Completed card creates detail route with fetched image and plant ID',
    (tester) async {
      store.images = [imageData()];
      final routes = _Routes();
      await HttpOverrides.runZoned(() async {
        await pumpCard(tester, imageId: 'img_001', routes: routes);
        await tester.tap(find.text('Test Plant'));
        await tester.idle();
        expect(routes.pushed, hasLength(2));
        // Inspect the destination before mounting its unrelated model pipeline.
        final route = routes.pushed.last as MaterialPageRoute;
        final destination =
            route.builder(tester.element(find.byType(CardWidget)))
                as SegmentPage;
        expect(destination.imgSrc, 'https://test.invalid/image.png');
        expect(destination.plantId, 'plant_001');
        expect(destination.id, 'img_001');
        await tester.pumpWidget(const SizedBox.shrink());
      }, createHttpClient: ImageHttpOverrides().createHttpClient);
    },
  );

  testWidgets('Incomplete cloud card does not navigate even with an image', (
    tester,
  ) async {
    store.images = [imageData()];
    final routes = _Routes();
    await HttpOverrides.runZoned(() async {
      await pumpCard(
        tester,
        imageId: 'img_001',
        completed: false,
        routes: routes,
      );
      await tester.tap(find.text('Test Plant'));
      await tester.idle();
      expect(routes.pushed, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: ImageHttpOverrides().createHttpClient);
  });

  testWidgets('Cancelling deletion leaves storage and callback untouched', (
    tester,
  ) async {
    var callbacks = 0;
    await pumpCard(tester, onDelete: () => callbacks++);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(store.deleted, isEmpty);
    expect(callbacks, 0);
  });

  testWidgets(
    'Confirmed deletion disables repeat action and calls callback only after storage completes',
    (tester) async {
      final pending = Completer<void>();
      store.deletion = pending.future;
      var callbacks = 0;
      await pumpCard(tester, onDelete: () => callbacks++);
      await confirmDelete(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.deleted, ['plants/plant_001']);
      expect(callbacks, 0);
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(button.onPressed, isNull);
      pending.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.updated, ['users/test-user']);
      expect(callbacks, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Failed deletion reports error without success callback', (
    tester,
  ) async {
    store.queryError = StateError('simulated deletion failure');
    var callbacks = 0;
    await pumpCard(tester, onDelete: () => callbacks++);
    await confirmDelete(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(callbacks, 0);
    expect(store.deleted, isEmpty);
    expect(find.textContaining('Could not delete:'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
