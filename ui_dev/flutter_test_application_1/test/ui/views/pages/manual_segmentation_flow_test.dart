import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/views/pages/mask_editor_page.dart';
import 'package:flutter_test_application_1/views/pages/segmentation_mode_page.dart';

const int _imageWidth = 100;
const int _imageHeight = 80;

Uint8List _bannerPng() =>
    File('assets/images/appn_banner.png').readAsBytesSync();

Uint8List _blankPng() => Uint8List.fromList(
  img.encodePng(img.Image(width: _imageWidth, height: _imageHeight)),
);

void main() {
  testWidgets('mode page offers both manual and automatic', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SegmentationModePage(imageBytes: _bannerPng())),
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
                              (context) => SegmentationModePage(
                                imageBytes: _bannerPng(),
                              ),
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

  group('manual mask flow', () {
    // Holds whatever the editor pops, so a test can assert on the request the
    // manual flow hands to batch processing.
    late BatchSegmentationRequest? popped;

    Future<void> pumpEditor(WidgetTester tester) async {
      popped = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () async {
                        popped = await Navigator.of(
                          context,
                        ).push<BatchSegmentationRequest>(
                          MaterialPageRoute(
                            builder:
                                (context) => MaskEditorPage(
                                  imageId: 'image-1',
                                  plantId: 'plant-1',
                                  imageUrl: 'file:///drone.jpg',
                                  imageBytes: _blankPng(),
                                  imageWidth: _imageWidth,
                                  imageHeight: _imageHeight,
                                  initialMasks: const [],
                                  source: SegmentationSource.manual,
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
    }

    testWidgets('opens with a blank mask, brush armed and nothing to undo', (
      tester,
    ) async {
      await pumpEditor(tester);

      expect(find.text('Paint leaf masks'), findsOneWidget);
      expect(find.byKey(const Key('brush-size-slider')), findsOneWidget);
      // The starting mask is not an edit, so there is nothing to step back to.
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('undo-mask-button')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('process-masks-button')),
            )
            .onPressed,
        isNull,
        reason: 'nothing painted yet',
      );
    });

    testWidgets('a tap dabs paint, so the brush works without a drag', (
      tester,
    ) async {
      await pumpEditor(tester);

      // Nothing is under the cursor on a blank canvas, so the tap must reach
      // the brush rather than being read as a deselect.
      await tester.tapAt(
        tester
            .getRect(find.byKey(const Key('mask-editor-gesture-area')))
            .center,
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('process-masks-button')),
            )
            .onPressed,
        isNotNull,
        reason: 'the dab is a usable mask',
      );
    });

    testWidgets('painting a leaf produces a hand-painted mask request', (
      tester,
    ) async {
      await pumpEditor(tester);

      // A real drag, not dragFrom: the stroke has to clear the drag slop
      // before the canvas starts painting.
      final rect = tester.getRect(
        find.byKey(const Key('mask-editor-gesture-area')),
      );
      final stroke = await tester.startGesture(rect.center);
      await tester.pump();
      await stroke.moveBy(const Offset(40, 0));
      await tester.pump();
      await stroke.moveBy(const Offset(0, 30));
      await tester.pump();
      await stroke.up();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('undo-mask-button')))
            .onPressed,
        isNotNull,
        reason: 'the stroke is undoable',
      );

      final process = find.byKey(const Key('process-masks-button'));
      expect(tester.widget<FilledButton>(process).onPressed, isNotNull);
      await tester.tap(process);
      await tester.pumpAndSettle();

      expect(popped, isNotNull);
      expect(popped!.masks, hasLength(1));
      // One bbox label per mask, so the batch pipeline is reused unchanged.
      expect(popped!.labels, hasLength(1));
      expect(popped!.imageId, 'image-1');

      final json = popped!.toJson();
      expect(json['segmentationSource'], 'manual');
      expect(json['maskCount'], 1);
      expect(json['coordinateSpace'], 'normalized_original_image');
    });
  });
}
