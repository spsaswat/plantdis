import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/models/leaf_mask.dart';

/// A filled [width]x[height] mask at ([left], [top]).
LeafMask filled({
  required int left,
  required int top,
  required int width,
  required int height,
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
  group('containsImagePixel', () {
    test('answers in full-image coordinates, not bbox-local ones', () {
      final mask = filled(left: 10, top: 20, width: 4, height: 4);

      expect(mask.containsImagePixel(10, 20), isTrue);
      expect(mask.containsImagePixel(13, 23), isTrue);
      expect(mask.containsImagePixel(14, 23), isFalse);
      expect(mask.containsImagePixel(0, 0), isFalse);
    });
  });

  group('toNormalizedRect', () {
    test('maps the bbox onto 0-1 image space', () {
      final mask = filled(left: 100, top: 150, width: 200, height: 300);

      final rect = mask.toNormalizedRect(400, 600);

      expect(rect.x, closeTo(0.25, 1e-9));
      expect(rect.y, closeTo(0.25, 1e-9));
      expect(rect.width, closeTo(0.5, 1e-9));
      expect(rect.height, closeTo(0.5, 1e-9));
    });

    test('stays within bounds for a mask touching the far edge', () {
      final mask = filled(left: 390, top: 590, width: 10, height: 10);

      final rect = mask.toNormalizedRect(400, 600);

      expect(rect.x + rect.width, lessThanOrEqualTo(1.0));
      expect(rect.y + rect.height, lessThanOrEqualTo(1.0));
    });
  });

  group('expandedToInclude', () {
    test('grows the bbox and keeps existing pixels at the right offset', () {
      final mask = filled(left: 10, top: 10, width: 2, height: 2);

      final grown = mask.expandedToInclude(
        const math.Rectangle<int>(4, 6, 4, 4),
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(grown.left, 4);
      expect(grown.top, 6);
      expect(grown.width, 8); // 4..11
      expect(grown.height, 6); // 6..11
      // The original block moved, not the pixels it marks.
      expect(grown.containsImagePixel(10, 10), isTrue);
      expect(grown.containsImagePixel(11, 11), isTrue);
      expect(grown.containsImagePixel(4, 6), isFalse);
      expect(grown.pixelCount, 4);
    });

    test('clamps the expansion to the image and returns itself when covered', () {
      final mask = filled(left: 0, top: 0, width: 10, height: 10);

      final grown = mask.expandedToInclude(
        const math.Rectangle<int>(-50, -50, 20, 20),
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(grown.left, 0);
      expect(grown.top, 0);
      expect(identical(grown, mask), isTrue);
    });
  });

  group('tightened', () {
    test('shrinks to the remaining pixels after an erase', () {
      final mask = filled(left: 5, top: 5, width: 6, height: 6);
      // Erase everything except a 2x2 block at bbox-local (2,3).
      for (var y = 0; y < 6; y++) {
        for (var x = 0; x < 6; x++) {
          final keep = x >= 2 && x <= 3 && y >= 3 && y <= 4;
          mask.bytes[y * 6 + x] = keep ? 1 : 0;
        }
      }

      final tight = mask.tightened();

      expect(tight.left, 7);
      expect(tight.top, 8);
      expect(tight.width, 2);
      expect(tight.height, 2);
      expect(tight.pixelCount, 4);
      expect(tight.containsImagePixel(7, 8), isTrue);
    });

    test('reports empty when everything was erased', () {
      final mask = LeafMask(
        left: 3,
        top: 4,
        width: 5,
        height: 5,
        bytes: Uint8List(25),
      );

      expect(mask.isEmpty, isTrue);
      expect(mask.tightened().isEmpty, isTrue);
    });
  });

  group('emptyAt and deepCopy', () {
    test('emptyAt spans the image with no set pixels', () {
      final mask = LeafMask.emptyAt(imageWidth: 40, imageHeight: 30);

      expect(mask.width, 40);
      expect(mask.height, 30);
      expect(mask.isEmpty, isTrue);
    });

    test('deepCopy does not share its buffer', () {
      final mask = filled(left: 0, top: 0, width: 3, height: 3);
      final copy = mask.deepCopy();

      copy.bytes[0] = 0;

      expect(mask.bytes[0], 1);
    });
  });
}
