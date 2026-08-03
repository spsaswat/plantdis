import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/drone_batch_model.dart';
import 'package:flutter_test_application_1/services/batch_processing_service.dart';
import 'package:flutter_test_application_1/views/widgets/leaf_region_overlay.dart';

/// A real (if tiny) PNG: an empty MemoryImage fails to decode and surfaces as
/// a test error even though the widget has an errorBuilder.
final Uint8List _tinyPng = Uint8List.fromList(
  img.encodePng(img.Image(width: 4, height: 4)),
);

BatchLeafEntry _leaf(int index, String status, {String? disease}) {
  return BatchLeafEntry(
    labelId: 'label_${index + 1}',
    index: index,
    region: NormalizedLabelRect(
      x: 0.1 * index,
      y: 0.1,
      width: 0.1,
      height: 0.1,
    ),
    status: status,
    detectedDisease: disease,
  );
}

void main() {
  group('BatchProgress', () {
    test('counts finished as completed plus failed', () {
      const progress = BatchProgress(
        batchId: 'b1',
        total: 5,
        completed: 3,
        failed: 1,
      );

      expect(progress.finished, 4);
      expect(progress.fraction, closeTo(0.8, 0.0001));
    });

    test('does not divide by zero for an empty batch', () {
      const progress = BatchProgress(
        batchId: 'b1',
        total: 0,
        completed: 0,
        failed: 0,
      );

      expect(progress.fraction, 0);
    });
  });

  group('leafStatusColor', () {
    testWidgets('distinguishes healthy, diseased, failed and pending', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return const SizedBox();
            },
          ),
        ),
      );

      final healthy = _leaf(0, LeafStatus.completed, disease: 'Apple___healthy');
      final diseased = _leaf(
        1,
        LeafStatus.completed,
        disease: 'Apple___Black_rot',
      );
      final failed = _leaf(2, LeafStatus.error);
      final pending = _leaf(3, LeafStatus.pending);

      expect(leafStatusColor(healthy, scheme), Colors.green);
      expect(leafStatusColor(diseased, scheme), Colors.orange);
      expect(leafStatusColor(failed, scheme), scheme.error);
      expect(leafStatusColor(pending, scheme), Colors.grey);
    });
  });

  group('LeafRegionFrame', () {
    testWidgets('hugs the image instead of leaving background bars', (
      tester,
    ) async {
      // A wide desktop window with a landscape drone image: the frame must be
      // as wide as the image at that height, not as wide as the window, or the
      // leftover background shows as black bars beside the image.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LeafRegionFrame(
                    image: MemoryImage(_tinyPng),
                    imageAspectRatio: 4 / 3,
                    maxHeight: 280,
                    entries: [_leaf(0, LeafStatus.pending)],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(LeafRegionOverlay));

      expect(size.height, closeTo(280, 0.5));
      expect(size.width, closeTo(280 * 4 / 3, 0.5));
      expect(size.width / size.height, closeTo(4 / 3, 0.01));
    });

    testWidgets('falls back to the width when height is not the limit', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LeafRegionFrame(
                    image: MemoryImage(_tinyPng),
                    imageAspectRatio: 4 / 3,
                    maxHeight: 280,
                    entries: [_leaf(0, LeafStatus.pending)],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(LeafRegionOverlay));

      expect(size.width, closeTo(300, 0.5));
      expect(size.height, closeTo(225, 0.5));
    });

    testWidgets('renders a placeholder when the image source is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeafRegionFrame(
              image: plantImageProvider(null),
              imageAspectRatio: 4 / 3,
              entries: const [],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.byType(LeafRegionOverlay), findsNothing);
    });
  });

  group('LeafRegionOverlay', () {
    testWidgets('reports the leaf whose box was tapped', (tester) async {
      final entries = [
        _leaf(0, LeafStatus.completed, disease: 'Apple___healthy'),
        _leaf(5, LeafStatus.completed, disease: 'Apple___Black_rot'),
      ];
      BatchLeafEntry? tapped;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              // 400x400 box with a 1:1 image => the canvas is the full 400x400.
              child: SizedBox(
                width: 400,
                height: 400,
                child: LeafRegionOverlay(
                  image: MemoryImage(_tinyPng),
                  imageAspectRatio: 1,
                  entries: entries,
                  onLeafTap: (entry) => tapped = entry,
                ),
              ),
            ),
          ),
        ),
      );

      // tapAt takes global coordinates, so offsets are measured from the
      // overlay's own top-left corner.
      final origin = tester.getTopLeft(find.byType(LeafRegionOverlay));

      // Leaf index 5 spans x 0.5-0.6, y 0.1-0.2 => centre (0.55, 0.15) of 400.
      await tester.tapAt(origin + const Offset(220, 60));
      await tester.pump();
      expect(tapped?.labelId, 'label_6');

      // Leaf index 0 spans x 0.0-0.1, y 0.1-0.2 => centre (0.05, 0.15) of 400.
      await tester.tapAt(origin + const Offset(20, 60));
      await tester.pump();
      expect(tapped?.labelId, 'label_1');
    });

    testWidgets('ignores taps outside every box', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: LeafRegionOverlay(
                  image: MemoryImage(_tinyPng),
                  imageAspectRatio: 1,
                  entries: [_leaf(0, LeafStatus.pending)],
                  onLeafTap: (_) => taps++,
                ),
              ),
            ),
          ),
        ),
      );

      // Bottom-right corner is well clear of the single box near the top-left.
      final origin = tester.getTopLeft(find.byType(LeafRegionOverlay));
      await tester.tapAt(origin + const Offset(380, 380));
      await tester.pump();

      expect(taps, 0);
    });
  });
}
