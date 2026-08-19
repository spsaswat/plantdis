import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/views/pages/mask_review_page.dart';
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
      controller.setBrushRadius(3);

      // Centred just past the right edge, so the disc overlaps the block.
      controller.applyStroke([const Offset(31, 20)]);

      expect(controller.masks.first.mask.containsImagePixel(32, 20), isTrue);
    });

    test('erase removes pixels and tightening shrinks the bbox', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 40, height: 40)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.erase);
      controller.setBrushRadius(30);

      // Wipe the right half of the block.
      controller.applyStroke([
        const Offset(60, 10),
        const Offset(60, 50),
      ]);

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
      controller.setBrushRadius(4);
      controller.applyStroke([const Offset(31, 20)]);
      expect(controller.masks.first.mask.containsImagePixel(33, 20), isTrue);

      controller.undo();

      expect(controller.masks.first.mask.containsImagePixel(33, 20), isFalse);
    });

    test('buildFinalMasks drops a mask that was erased away', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 6, height: 6)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.erase);
      controller.setBrushRadius(20);
      controller.applyStroke([const Offset(13, 13)]);

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
      controller.setBrushRadius(2);

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
      controller.setBrushRadius(5);

      controller.applyStroke([const Offset(30, 30)]);

      // The gap is enclosed by the surrounding mask, so it is sealed again.
      expect(controller.masks.first.mask.containsImagePixel(30, 30), isTrue);

      // Erasing in from an edge still trims, which is what the tool is for.
      controller.setBrushRadius(12);
      controller.applyStroke([const Offset(10, 30)]);
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
      controller.setBrushRadius(4);

      // Cut the bridge.
      controller.applyStroke([const Offset(25, 10)]);

      final mask = controller.masks.first.mask;
      expect(mask.containsImagePixel(45, 10), isTrue, reason: 'larger end');
      expect(mask.containsImagePixel(5, 10), isFalse, reason: 'smaller end');
      expect(controller.buildFinalMasks(), hasLength(1));
    });

    test('a detached dab of paint does not become a second piece', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 30, height: 30)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.paint);
      controller.setBrushRadius(2);

      // Paint well clear of the existing block.
      controller.applyStroke([const Offset(80, 70)]);

      expect(
        controller.masks.first.mask.containsImagePixel(80, 70),
        isFalse,
        reason: 'detached from the leaf, so it is not part of it',
      );
      expect(controller.masks.first.mask.containsImagePixel(20, 20), isTrue);
    });

    test('paint that bridges back to the leaf is kept', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 30, height: 30)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.paint);
      controller.setBrushRadius(3);

      // A stroke starting on the leaf and extending outward stays connected.
      controller.applyStroke(const [Offset(35, 25), Offset(60, 25)]);

      expect(controller.masks.first.mask.containsImagePixel(58, 25), isTrue);
    });

    test('undo steps back over the whole normalized stroke', () {
      final controller = MaskEditorController(
        imageWidth: kImageWidth,
        imageHeight: kImageHeight,
        initialMasks: [block(left: 10, top: 10, width: 30, height: 30)],
      );
      controller.select(controller.masks.first.id);
      controller.setTool(MaskTool.erase);
      controller.setBrushRadius(6);
      controller.applyStroke([const Offset(10, 25)]);
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
      controller.setBrushRadius(30);
      controller.applyStroke([const Offset(20, 20)]);

      expect(captured.containsImagePixel(20, 20), isTrue);
    });
  });

  group('MaskReviewPage', () {
    Future<BatchSegmentationRequest?> pumpPage(
      WidgetTester tester,
      List<LeafMask> masks,
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
                                (context) => MaskReviewPage(
                                  imageId: 'image-1',
                                  plantId: 'plant-1',
                                  imageUrl: 'file:///drone.jpg',
                                  imageBytes: testPng(),
                                  imageWidth: kImageWidth,
                                  imageHeight: kImageHeight,
                                  initialMasks: masks,
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
            Offset(rect.width * 10 / kImageWidth,
                rect.height * 10 / kImageHeight),
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
                                (context) => MaskReviewPage(
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
      expect(result!.hasMasks, isTrue);
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
      expect(
        find.textContaining('Add at least one mask'),
        findsOneWidget,
      );
    });
  });
}
