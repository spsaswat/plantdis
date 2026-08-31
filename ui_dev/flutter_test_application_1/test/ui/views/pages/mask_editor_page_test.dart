import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/views/pages/mask_editor_page.dart';
import 'package:flutter_test_application_1/views/widgets/mask_editor_controller.dart';

const int kImageWidth = 100;
const int kImageHeight = 80;

Uint8List testPng() => Uint8List.fromList(
  img.encodePng(img.Image(width: kImageWidth, height: kImageHeight)),
);

LeafMask block({
  required int left,
  required int top,
  int width = 20,
  int height = 20,
}) {
  return LeafMask(
    left: left,
    top: top,
    width: width,
    height: height,
    bytes: Uint8List(width * height)..fillRange(0, width * height, 1),
  );
}

/// A closed rectangular lasso path. Both tools take a boundary, never a dab,
/// so every stroke in these tests goes round something.
List<Offset> lassoBox(int left, int top, int right, int bottom) => [
  Offset(left.toDouble(), top.toDouble()),
  Offset(right.toDouble(), top.toDouble()),
  Offset(right.toDouble(), bottom.toDouble()),
  Offset(left.toDouble(), bottom.toDouble()),
  Offset(left.toDouble(), top.toDouble()),
];

void main() {
  group('MaskEditorController', () {
    test('paint extends the selected mask outward from its edge', () {
      // The block spans x 10..29, y 10..29.
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.paint);

      // A loop overlapping the block's right edge, so the two join up.
      controller.applyStroke(lassoBox(25, 15, 40, 25));

      expect(controller.masks.first.mask.containsImagePixel(35, 20), isTrue);
      expect(controller.masks.first.mask.containsImagePixel(15, 15), isTrue);
    });

    test('the fixed trace width is converted at the current zoom', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
      );

      // The internal boundary is two screen pixels wide. Fitted 1:1, that is
      // a half-pixel radius before rasterization rounds it to a disc.
      controller.setViewScale(1);
      expect(controller.penRadiusImagePx, 0.5);

      // Zoomed 4x, it bottoms out at a one-image-pixel trace.
      controller.setViewScale(0.25);
      expect(controller.penRadiusImagePx, 0);
    });

    test('the fixed trace is a boundary and adds no width to the mask', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
      );
      controller.addEmptyMask();
      controller.setViewScale(1);
      controller.applyStroke(lassoBox(20, 20, 60, 60));

      final mask = controller.masks.first.mask;
      expect(mask.left, closeTo(20, 1));
      expect(mask.top, closeTo(20, 1));
      expect(mask.width, closeTo(41, 2));
      expect(mask.height, closeTo(41, 2));
    });

    test('a stroke across the leaf does not cut it in two', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
      );
      controller.addEmptyMask();
      controller.setViewScale(1);
      // A bowtie: the line crosses itself in the middle, the way a scribbled
      // trace does. That splits what it encloses into two lobes, and the leaf
      // has to be both of them rather than the larger one.
      controller.applyStroke(const [
        Offset(20, 20),
        Offset(60, 20),
        Offset(20, 60),
        Offset(60, 60),
        Offset(20, 20),
      ]);

      final mask = controller.masks.first.mask;
      expect(mask.containsImagePixel(40, 26), isTrue, reason: 'upper lobe');
      expect(mask.containsImagePixel(40, 54), isTrue, reason: 'lower lobe');
    });

    test('a loop that stops short of its start still encloses a leaf', () {
      final controller = MaskEditorController(
        imageWidth: 400,
        imageHeight: 400,
      );
      controller.addEmptyMask();
      controller.setViewScale(1);

      // A circle traced by hand, lifted 12 degrees short of where it began.
      // Drawing round a leaf looks like this every time.
      final circle = <Offset>[
        for (var degrees = 0; degrees <= 348; degrees += 4)
          Offset(
            200 + 90 * math.cos(degrees * math.pi / 180),
            200 + 90 * math.sin(degrees * math.pi / 180),
          ),
      ];
      controller.applyStroke(circle);

      final mask = controller.masks.first.mask;
      expect(mask.containsImagePixel(200, 200), isTrue, reason: 'enclosed');
      // The leaf is the circle the pen went round, not a fraction of it.
      expect(mask.width, closeTo(181, 4));
      expect(mask.height, closeTo(181, 4));
    });

    test('an open stroke is closed end to end, the way a lasso is', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
      );
      controller.addEmptyMask();
      controller.setViewScale(1);

      // Three sides of a box: wide open, and nothing like a near miss.
      controller.applyStroke(const [
        Offset(70, 20),
        Offset(20, 20),
        Offset(20, 60),
        Offset(70, 60),
      ]);

      expect(controller.masks.first.mask.containsImagePixel(45, 40), isTrue);
      // The region runs all the way to the join, not just to the drawn sides.
      expect(
        controller.masks.first.mask.containsImagePixel(68, 40),
        isTrue,
        reason: 'up to the closing segment',
      );
    });

    test('a tail on the end of a stroke is not part of the leaf', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
      );
      controller.addEmptyMask();
      controller.setViewScale(1);

      // A stroke that wanders in from the top left before tracing the box,
      // which is what starting to draw slightly early looks like.
      controller.applyStroke(const [
        Offset(5, 5),
        Offset(20, 20),
        Offset(60, 20),
        Offset(60, 60),
        Offset(20, 60),
        Offset(20, 20),
      ]);

      final mask = controller.masks.first.mask;
      expect(mask.containsImagePixel(40, 40), isTrue, reason: 'enclosed');
      // The lead-in encloses nothing, so it is not leaf.
      expect(mask.containsImagePixel(5, 5), isFalse, reason: 'the tail');
      expect(mask.containsImagePixel(12, 12), isFalse, reason: 'the tail');
      // The traced line is the leaf's edge, so the leaf reaches it exactly.
      expect(mask.left, 20);
      expect(mask.top, 20);
    });

    test('an erase lasso takes out what it encloses', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
      );
      controller.addEmptyMask();
      controller.setViewScale(1);
      controller.applyStroke(lassoBox(20, 20, 60, 60));
      expect(controller.masks.first.mask.containsImagePixel(50, 40), isTrue);

      // A loop over the right side of the leaf, drawn like any other line.
      controller.setTool(MaskTool.erase);
      controller.applyStroke(lassoBox(45, 10, 70, 70));

      final mask = controller.masks.first.mask;
      expect(mask.containsImagePixel(50, 40), isFalse, reason: 'taken out');
      expect(mask.containsImagePixel(30, 40), isTrue, reason: 'left alone');
      expect(mask.left + mask.width, lessThan(50));
    });

    test('an erase lasso inside a leaf leaves it whole', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
      );
      controller.addEmptyMask();
      controller.setViewScale(1);
      controller.applyStroke(lassoBox(20, 20, 60, 60));
      final whole = controller.masks.first.mask.pixelCount;

      // A leaf has no holes in it, so a loop drawn well inside seals again.
      controller.setTool(MaskTool.erase);
      controller.applyStroke(lassoBox(35, 35, 45, 45));

      expect(controller.masks.first.mask.pixelCount, whole);
      expect(controller.masks.first.mask.containsImagePixel(40, 40), isTrue);
    });

    test('erase removes pixels and tightening shrinks the bbox', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 40, height: 40)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.erase);

      // Wipe the right half of the block.
      controller.applyStroke(lassoBox(35, 5, 60, 55));

      final finalMask = controller.buildFinalMasks().single;
      expect(finalMask.containsImagePixel(48, 30), isFalse);
      expect(finalMask.width, lessThan(40));
    });

    test('undo restores the mask as it was before a stroke', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.paint);
      controller.applyStroke(lassoBox(25, 15, 40, 25));
      expect(controller.masks.first.mask.containsImagePixel(35, 20), isTrue);

      controller.undo();

      expect(controller.masks.first.mask.containsImagePixel(35, 20), isFalse);
    });

    test('buildFinalMasks drops a mask that was erased away', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 6, height: 6)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.erase);
      controller.applyStroke(lassoBox(5, 5, 25, 25));

      expect(controller.maskCount, 1);
      expect(controller.buildFinalMasks(), isEmpty);
      expect(controller.hasUsableMasks, isFalse);
    });

    test('seals holes in the masks it is constructed with', () {
      // A ring: solid border, hollow middle.
      final bytes = Uint8List(20 * 20);
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 20; x++) {
          if (x < 3 || y < 3 || x >= 17 || y >= 17) bytes[y * 20 + x] = 1;
        }
      }
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [
          LeafMask(left: 10, top: 10, width: 20, height: 20, bytes: bytes),
        ],
      );

      expect(controller.masks.first.mask.containsImagePixel(20, 20), isTrue);
      expect(controller.buildFinalMasks().single.pixelCount, 20 * 20);
    });

    test('a stroke that loops back on itself leaves no gap inside', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: const [],
      );
      controller.addEmptyMask();

      // Trace the outline of a square without filling it in.
      controller.applyStroke(const [
        Offset(20, 20),
        Offset(40, 20),
        Offset(40, 40),
        Offset(20, 40),
        Offset(20, 20),
      ]);

      // The enclosed middle is filled even though the brush never crossed it.
      expect(controller.masks.first.mask.containsImagePixel(30, 30), isTrue);
    });

    test('erasing into the middle trims nothing, since a leaf stays solid', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 40, height: 40)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.erase);

      controller.applyStroke(lassoBox(25, 25, 35, 35));

      // The gap is enclosed by the surrounding mask, so it is sealed again.
      expect(controller.masks.first.mask.containsImagePixel(30, 30), isTrue);

      // Erasing in from an edge still trims, which is what the tool is for.
      controller.applyStroke(lassoBox(5, 25, 20, 35));
      expect(controller.masks.first.mask.containsImagePixel(10, 30), isFalse);
    });

    test('erasing through the waist keeps only the larger part', () {
      // A dumbbell: two blocks joined by a thin bridge.
      final bytes = Uint8List(60 * 20);
      void fillRect(int x0, int y0, int x1, int y1) {
        for (var y = y0; y <= y1; y++) {
          for (var x = x0; x <= x1; x++) {
            bytes[y * 60 + x] = 1;
          }
        }
      }

      fillRect(0, 0, 14, 19); // small end
      fillRect(15, 9, 34, 10); // bridge
      fillRect(35, 0, 59, 19); // large end

      final controller = MaskEditorController(
        imageWidth: 200,
        imageHeight: 200,
        initialMasks: [
          LeafMask(left: 0, top: 0, width: 60, height: 20, bytes: bytes),
        ],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.erase);

      // Cut the bridge.
      controller.applyStroke(lassoBox(20, 5, 30, 15));

      final mask = controller.masks.first.mask;
      expect(mask.containsImagePixel(45, 10), isTrue, reason: 'larger end');
      expect(mask.containsImagePixel(5, 10), isFalse, reason: 'smaller end');
      expect(controller.buildFinalMasks(), hasLength(1));
    });

    test('paint drawn clear of the shape replaces it', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 30, height: 30)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.paint);

      // Redrawing the outline somewhere else means the first attempt was
      // wrong, so the new loop wins even though it is much smaller.
      controller.applyStroke(lassoBox(70, 60, 90, 75));

      expect(controller.masks.first.mask.containsImagePixel(80, 70), isTrue);
      expect(
        controller.masks.first.mask.containsImagePixel(20, 20),
        isFalse,
        reason: 'the shape it replaced is gone',
      );
    });

    test('undo brings back a shape a detached stroke replaced', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 30, height: 30)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.paint);
      controller.applyStroke(lassoBox(70, 60, 90, 75));

      controller.undo();

      expect(controller.masks.first.mask.containsImagePixel(20, 20), isTrue);
      expect(controller.masks.first.mask.containsImagePixel(80, 70), isFalse);
    });

    test('paint that bridges back to the leaf is kept', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 30, height: 30)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.paint);

      // A loop overlapping the leaf and reaching past it stays joined on.
      controller.applyStroke(lassoBox(35, 20, 60, 30));

      expect(controller.masks.first.mask.containsImagePixel(58, 25), isTrue);
      expect(controller.masks.first.mask.containsImagePixel(15, 15), isTrue);
    });

    test('undo steps back over the whole normalized stroke', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 30, height: 30)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.erase);
      controller.applyStroke(lassoBox(5, 20, 18, 30));
      expect(controller.masks.first.mask.containsImagePixel(10, 25), isFalse);

      controller.undo();

      expect(controller.masks.first.mask.containsImagePixel(10, 25), isTrue);
      expect(controller.masks.first.mask.pixelCount, 30 * 30);
    });

    test('final masks are copies, so later edits do not mutate a request', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10)],
      );
      final captured = controller.buildFinalMasks().single;

      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.erase);
      controller.applyStroke(lassoBox(5, 5, 35, 35));

      expect(captured.containsImagePixel(20, 20), isTrue);
    });
  });

  group('MaskEditorPage', () {
    Future<BatchSegmentationRequest?> pumpPage(
      WidgetTester tester,
      List<LeafMask> masks, {
      SegmentationSource source = SegmentationSource.sam,
    }) async {
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
                                (context) => MaskEditorPage(
                                  imageId: 'image-1',
                                  plantId: 'plant-1',
                                  imageUrl: 'file:///drone.jpg',
                                  imageBytes: testPng(),
                                  imageWidth: kImageWidth,
                                  imageHeight: kImageHeight,
                                  initialMasks: masks,
                                  source: source,
                                ),
                          ),
                        );
                      },
                      child: const Text('Open review'),
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('manual drawing opens the illustrated help from the app bar', (
      tester,
    ) async {
      await pumpPage(tester, const [], source: SegmentationSource.manual);

      expect(find.byKey(const Key('mask-drawing-help-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mask-drawing-help-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mask-drawing-help-dialog')), findsOneWidget);
      expect(find.text('How to draw leaf masks'), findsOneWidget);
      expect(find.text('Trace the first leaf'), findsOneWidget);
      expect(find.text('Add the next leaf'), findsOneWidget);
      for (var step = 1; step <= 4; step++) {
        expect(find.byKey(Key('mask-help-step-$step')), findsOneWidget);
      }

      await tester.tap(find.byKey(const Key('close-mask-drawing-help-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mask-drawing-help-dialog')), findsNothing);
      expect(find.byKey(const Key('mask-editor-gesture-area')), findsOneWidget);
    });

    testWidgets('mask review opens its own illustrated help', (tester) async {
      await pumpPage(tester, [block(left: 5, top: 5)]);

      expect(find.byKey(const Key('mask-drawing-help-button')), findsNothing);
      expect(find.byKey(const Key('mask-review-help-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mask-review-help-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mask-review-help-dialog')), findsOneWidget);
      expect(find.text('How to review leaf masks'), findsOneWidget);
      expect(find.text('Select a mask'), findsOneWidget);
      expect(find.text('Correct the selected mask'), findsOneWidget);
      expect(find.text('Handle missed or extra leaves'), findsOneWidget);

      await tester.tap(find.byKey(const Key('close-mask-review-help-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mask-review-help-dialog')), findsNothing);
      expect(find.byKey(const Key('mask-editor-gesture-area')), findsOneWidget);
    });

    testWidgets('opens on the pen, and the selector reaches the erase', (
      tester,
    ) async {
      await pumpPage(tester, [block(left: 5, top: 5)]);

      SegmentedButton<MaskTool> selector() =>
          tester.widget(find.byKey(const Key('mask-tool-selector')));

      // There is no tool for moving the view any more, so the editor has to
      // open on one that draws.
      expect(selector().selected, {MaskTool.paint});
      expect(selector().segments, hasLength(2));

      await tester.tap(find.text('Erase'));
      await tester.pumpAndSettle();

      expect(selector().selected, {MaskTool.erase});
    });

    testWidgets('shows how many masks were loaded', (tester) async {
      await pumpPage(tester, [
        block(left: 5, top: 5),
        block(left: 50, top: 40),
      ]);

      expect(
        tester.widget<Text>(find.byKey(const Key('mask-count'))).data,
        '2 masks',
      );
    });

    testWidgets('adding a mask raises the count', (tester) async {
      await pumpPage(tester, [block(left: 5, top: 5)]);

      await tester.tap(find.byKey(const Key('add-mask-button')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('mask-count'))).data,
        '2 masks',
      );
    });

    testWidgets('selecting a mask enables delete, which lowers the count', (
      tester,
    ) async {
      await pumpPage(tester, [
        block(left: 5, top: 5),
        block(left: 50, top: 40),
      ]);

      final deleteButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('delete-mask-button')),
      );
      expect(deleteButton.onPressed, isNull, reason: 'nothing selected yet');

      // Tap inside the first mask on the canvas to select it.
      final canvas = find.byKey(const Key('mask-editor-gesture-area'));
      final rect = tester.getRect(canvas);
      await tester.tapAt(
        rect.topLeft +
            Offset(
              rect.width * 10 / kImageWidth,
              rect.height * 10 / kImageHeight,
            ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete-mask-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('mask-count'))).data,
        '1 mask',
      );
    });

    testWidgets('process returns bbox labels aligned with the masks', (
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
                                (context) => MaskEditorPage(
                                  imageId: 'image-1',
                                  plantId: 'plant-1',
                                  imageUrl: 'file:///drone.jpg',
                                  imageBytes: testPng(),
                                  imageWidth: kImageWidth,
                                  imageHeight: kImageHeight,
                                  initialMasks: [
                                    block(left: 10, top: 8),
                                    block(left: 50, top: 40),
                                  ],
                                  source: SegmentationSource.sam,
                                ),
                          ),
                        );
                      },
                      child: const Text('Open review'),
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('process-masks-button')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.masks, hasLength(2));
      expect(result!.labels, hasLength(2));
      // Each label is its mask's bbox in normalized image space.
      expect(result!.labels.first.x, closeTo(10 / kImageWidth, 1e-9));
      expect(result!.labels.first.y, closeTo(8 / kImageHeight, 1e-9));
      expect(result!.labels.first.width, closeTo(20 / kImageWidth, 1e-9));
      expect(result!.toJson()['segmentationSource'], 'sam');
    });

    testWidgets('process is disabled with nothing to analyze', (tester) async {
      await pumpPage(tester, const []);

      final process = tester.widget<FilledButton>(
        find.byKey(const Key('process-masks-button')),
      );
      expect(process.onPressed, isNull);
      expect(find.textContaining('Add at least one mask'), findsOneWidget);
    });
  });
}
