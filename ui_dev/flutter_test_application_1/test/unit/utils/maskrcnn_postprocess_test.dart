import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/utils/maskrcnn_postprocess.dart';

LeafMask _rect(int left, int top, int width, int height) => LeafMask(
  left: left,
  top: top,
  width: width,
  height: height,
  bytes: Uint8List(width * height)..fillRange(0, width * height, 1),
);

void main() {
  group('tileStarts', () {
    test('pins the last tile to the far edge', () {
      expect(tileStarts(5280, 1024, 665), [
        0,
        665,
        1330,
        1995,
        2660,
        3325,
        3990,
        4256,
      ]);
    });

    test('exact fit adds no extra tile', () {
      expect(tileStarts(1024 + 665, 1024, 665), [0, 665]);
    });

    test('image smaller than a tile gets one window', () {
      expect(tileStarts(800, 1024, 665), [0]);
    });
  });

  group('touchesInnerTileEdge', () {
    bool touches(double x0, double y0, double x1, double y1, int tileLeft) =>
        touchesInnerTileEdge(
          x0: x0,
          y0: y0,
          x1: x1,
          y1: y1,
          tileLeft: tileLeft,
          tileTop: 0,
          tileWidth: 1024,
          tileHeight: 1024,
          imageWidth: 3000,
          imageHeight: 1024,
        );

    test('left edge counts only away from the image border', () {
      expect(touches(1, 100, 200, 200, 0), isFalse);
      expect(touches(1, 100, 200, 200, 665), isTrue);
    });

    test('right edge inside the image counts', () {
      expect(touches(800, 100, 1023, 200, 0), isTrue);
    });

    test('top and bottom on the image border do not count', () {
      expect(touches(100, 0, 200, 1024, 665), isFalse);
    });
  });

  group('pasteMaskRcnnMask', () {
    // Generated with torchvision 0.29 paste_masks_in_image(padding=1) > 0.5.
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/maskrcnn_paste_cases.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final tileWidth = fixture['tileWidth'] as int;
    final tileHeight = fixture['tileHeight'] as int;
    final maskSize = fixture['maskSize'] as int;
    final cases = fixture['cases'] as List;

    for (var i = 0; i < cases.length; i++) {
      test('matches torchvision, case $i', () {
        final c = cases[i] as Map<String, dynamic>;
        final box = (c['box'] as List).cast<num>();
        final mask = pasteMaskRcnnMask(
          probs: Float32List.fromList(
            (c['mask'] as List).cast<num>().map((v) => v.toDouble()).toList(),
          ),
          maskSize: maskSize,
          x0: box[0].toDouble(),
          y0: box[1].toDouble(),
          x1: box[2].toDouble(),
          y1: box[3].toDouble(),
          tileWidth: tileWidth,
          tileHeight: tileHeight,
        );
        final expected = c['expected'] as Map<String, dynamic>?;
        if (expected == null) {
          expect(mask, isNull);
          return;
        }
        expect(mask, isNotNull);
        expect(
          [mask!.left, mask.top, mask.width, mask.height],
          [
            expected['left'],
            expected['top'],
            expected['width'],
            expected['height'],
          ],
        );
        expect(mask.bytes.join(), expected['bits']);
      });
    }

    test('offset shifts the mask into image coordinates', () {
      final probs = Float32List(28 * 28)..fillRange(0, 28 * 28, 1);
      final mask =
          pasteMaskRcnnMask(
            probs: probs,
            maskSize: 28,
            x0: 10,
            y0: 10,
            x1: 30,
            y1: 30,
            tileWidth: 64,
            tileHeight: 64,
            offsetX: 1000,
            offsetY: 500,
          )!;
      expect(mask.left, greaterThanOrEqualTo(1000));
      expect(mask.top, greaterThanOrEqualTo(500));
    });

    test('all-zero probabilities give no mask', () {
      final mask = pasteMaskRcnnMask(
        probs: Float32List(28 * 28),
        maskSize: 28,
        x0: 10,
        y0: 10,
        x1: 30,
        y1: 30,
        tileWidth: 64,
        tileHeight: 64,
      );
      expect(mask, isNull);
    });
  });

  group('maskOverlapRatio', () {
    test('is relative to the smaller mask', () {
      expect(maskOverlapRatio(_rect(0, 0, 10, 10), _rect(5, 0, 2, 2)), 1.0);
      expect(maskOverlapRatio(_rect(0, 0, 10, 10), _rect(5, 0, 10, 10)), 0.5);
    });

    test('disjoint masks do not overlap', () {
      expect(maskOverlapRatio(_rect(0, 0, 10, 10), _rect(20, 20, 5, 5)), 0);
    });
  });

  group('mergeLeafDetections', () {
    test('keeps the higher-scoring duplicate', () {
      final best = _rect(0, 0, 10, 10);
      final merged = mergeLeafDetections([
        LeafDetection(mask: _rect(1, 1, 10, 10), score: 0.6),
        LeafDetection(mask: best, score: 0.9),
        LeafDetection(mask: _rect(50, 50, 5, 5), score: 0.7),
      ]);
      expect(merged, hasLength(2));
      expect(merged.first, same(best));
    });

    test('whole leaf beats a higher-scoring tile-cut piece', () {
      final whole = _rect(0, 0, 20, 10);
      final merged = mergeLeafDetections([
        LeafDetection(
          mask: _rect(10, 0, 10, 10),
          score: 0.99,
          cutByTileEdge: true,
        ),
        LeafDetection(mask: whole, score: 0.8),
      ]);
      expect(merged, [whole]);
    });

    test('keeps a cut piece no whole leaf covers', () {
      final merged = mergeLeafDetections([
        LeafDetection(
          mask: _rect(0, 0, 10, 10),
          score: 0.9,
          cutByTileEdge: true,
        ),
      ]);
      expect(merged, hasLength(1));
    });
  });
}
