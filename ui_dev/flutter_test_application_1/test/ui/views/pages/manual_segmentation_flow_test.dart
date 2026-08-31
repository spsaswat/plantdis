import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
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
                      mode = await Navigator.of(context).push<SegmentationMode>(
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

    testWidgets('opens with a blank mask, pen armed and nothing to undo', (
      tester,
    ) async {
      await pumpEditor(tester);

      expect(find.text('Draw leaf masks'), findsOneWidget);
      expect(find.byKey(const Key('pen-width-slider')), findsNothing);
      // The starting mask is not an edit, so there is nothing to step back to.
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('undo-mask-button')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('process-masks-button')))
            .onPressed,
        isNull,
        reason: 'nothing painted yet',
      );
    });

    testWidgets('a tap leaves nothing behind, since it encloses nothing', (
      tester,
    ) async {
      await pumpEditor(tester);

      await tester.tapAt(
        tester
            .getRect(find.byKey(const Key('mask-editor-gesture-area')))
            .center,
      );
      await tester.pumpAndSettle();

      // The tools are lassos, so a dot is not a smear of paint to undo — it
      // is nothing at all.
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('undo-mask-button')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('process-masks-button')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('the wheel zooms while the pen is armed', (tester) async {
      await pumpEditor(tester);

      final viewer = find.byType(InteractiveViewer);
      final before =
          tester
              .widget<InteractiveViewer>(viewer)
              .transformationController!
              .value
              .getMaxScaleOnAxis();

      // Scrolling is how zooming is done on a desktop, and the pen being armed
      // must not swallow it: zooming in is what makes the pen fine.
      final centre = tester.getCenter(viewer);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      tester.binding.handlePointerEvent(pointer.hover(centre));
      tester.binding.handlePointerEvent(pointer.scroll(const Offset(0, -120)));
      await tester.pumpAndSettle();

      final after =
          tester
              .widget<InteractiveViewer>(viewer)
              .transformationController!
              .value
              .getMaxScaleOnAxis();
      expect(after, greaterThan(before));
    });

    testWidgets('the right button drags the image instead of drawing', (
      tester,
    ) async {
      await pumpEditor(tester);

      final viewer = find.byType(InteractiveViewer);
      final transform =
          tester.widget<InteractiveViewer>(viewer).transformationController!;
      final centre = tester.getCenter(viewer);

      // Zoomed right out the image already fills the frame, so there is
      // nowhere to drag it to.
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      tester.binding.handlePointerEvent(pointer.hover(centre));
      tester.binding.handlePointerEvent(pointer.scroll(const Offset(0, -240)));
      await tester.pumpAndSettle();
      final before = transform.value.getTranslation();

      final drag = await tester.startGesture(
        centre,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await drag.moveBy(const Offset(-40, -30));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(
        transform.value.getTranslation(),
        isNot(before),
        reason: 'the view moved',
      );
      // A drag recognizer only takes the primary button, so nothing was drawn.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('process-masks-button')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('tracing round a leaf produces a hand-painted mask request', (
      tester,
    ) async {
      await pumpEditor(tester);

      // A real drag, not dragFrom: the stroke has to clear the drag slop
      // before the canvas starts drawing. It comes back to where it started,
      // because only a closed line encloses a leaf.
      final rect = tester.getRect(
        find.byKey(const Key('mask-editor-gesture-area')),
      );
      final stroke = await tester.startGesture(rect.center);
      await tester.pump();
      // One and a half laps of the box. The drag slop swallows the first move
      // or two, so a single lap would arrive missing a side — and a line that
      // does not close encloses no leaf.
      for (final leg in const [
        Offset(60, 0),
        Offset(0, 45),
        Offset(-60, 0),
        Offset(0, -45),
        Offset(60, 0),
        Offset(0, 45),
      ]) {
        await stroke.moveBy(leg);
        await tester.pump();
      }
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
