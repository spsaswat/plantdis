import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/views/pages/manual_segmentation_page.dart';
import 'package:flutter_test_application_1/views/pages/segmentation_mode_page.dart';

Uint8List _testPng() => File('assets/images/appn_banner.png').readAsBytesSync();

void main() {
  testWidgets('mode page offers both manual and automatic', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SegmentationModePage(imageBytes: _testPng())),
    );

    final manual = tester.widget<FilledButton>(
      find.byKey(const Key('manual-segmentation-button')),
    );
    final automatic = tester.widget<OutlinedButton>(
      find.byKey(const Key('automatic-segmentation-button')),
    );
    expect(manual.onPressed, isNotNull);
    expect(automatic.onPressed, isNotNull);
    expect(find.textContaining('Coming soon'), findsNothing);
  });

  testWidgets('picking automatic returns the automatic mode', (tester) async {
    SegmentationMode? mode;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      mode = await Navigator.of(
                        context,
                      ).push<SegmentationMode>(
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  SegmentationModePage(imageBytes: _testPng()),
                        ),
                      );
                    },
                    child: const Text('Choose mode'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Choose mode'));
    await tester.pumpAndSettle();
    final automatic = find.byKey(const Key('automatic-segmentation-button'));
    await tester.ensureVisible(automatic);
    await tester.tap(automatic);
    await tester.pumpAndSettle();

    expect(mode, SegmentationMode.automatic);
  });

  testWidgets('manual flow draws, undoes, reviews, and returns request', (
    tester,
  ) async {
    BatchSegmentationRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await Navigator.of(
                        context,
                      ).push<BatchSegmentationRequest>(
                        MaterialPageRoute(
                          builder:
                              (context) => ManualSegmentationPage(
                                imageId: 'image-1',
                                plantId: 'plant-1',
                                imageUrl: 'file:///image.jpg',
                                imageBytes: _testPng(),
                                imageSize: const Size(363, 79),
                              ),
                        ),
                      );
                    },
                    child: const Text('Open editor'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    final gestureArea = find.byKey(const Key('rectangle-label-gesture-area'));
    final rect = tester.getRect(gestureArea);
    await tester.dragFrom(
      rect.topLeft + Offset(rect.width * 0.1, rect.height * 0.2),
      Offset(rect.width * 0.4, rect.height * 0.3),
    );
    await tester.pump();
    expect(find.text('1 label'), findsOneWidget);

    await tester.tap(find.byKey(const Key('undo-label-button')));
    await tester.pump();
    expect(find.text('0 labels'), findsOneWidget);

    await tester.dragFrom(
      rect.topLeft + Offset(rect.width * 0.2, rect.height * 0.2),
      Offset(rect.width * 0.5, rect.height * 0.5),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-labels-button')));
    await tester.pumpAndSettle();
    expect(find.text('1 label ready'), findsOneWidget);

    final editButton = find.byKey(const Key('edit-labels-button'));
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    final undo = tester.widget<OutlinedButton>(
      find.byKey(const Key('undo-label-button')),
    );
    expect(undo.onPressed, isNull);

    await tester.tap(find.byKey(const Key('save-labels-button')));
    await tester.pumpAndSettle();
    final processButton = find.byKey(const Key('process-labels-button'));
    await tester.ensureVisible(processButton);
    await tester.tap(processButton);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.imageId, 'image-1');
    expect(result!.labels, hasLength(1));
    expect(result!.toJson()['coordinateSpace'], 'normalized_original_image');
  });
}
