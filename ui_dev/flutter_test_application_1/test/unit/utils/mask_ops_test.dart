import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/utils/mask_ops.dart';

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
  group('applyStrokeToMask', () {
    test('paints a disc into an empty mask', () {
      final mask = LeafMask.emptyAt(imageWidth: 100, imageHeight: 100);

      final painted = applyStrokeToMask(
        mask,
        const [math.Point<double>(50, 50)],
        radius: 5,
        erase: false,
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(painted.containsImagePixel(50, 50), isTrue);
      expect(painted.containsImagePixel(53, 50), isTrue);
      // Outside the radius.
      expect(painted.containsImagePixel(60, 50), isFalse);
    });

    test('fills the gaps between sampled points along a drag', () {
      final painted = applyStrokeToMask(
        LeafMask.emptyAt(imageWidth: 100, imageHeight: 100),
        const [math.Point<double>(10, 50), math.Point<double>(90, 50)],
        radius: 3,
        erase: false,
        imageWidth: 100,
        imageHeight: 100,
      );

      // A stroke sampled at only two points must still be continuous.
      for (var x = 10; x <= 90; x++) {
        expect(
          painted.containsImagePixel(x, 50),
          isTrue,
          reason: 'gap at x=$x',
        );
      }
    });

    test('grows the bbox when painting outside it', () {
      final mask = filled(left: 40, top: 40, width: 4, height: 4);

      final painted = applyStrokeToMask(
        mask,
        const [math.Point<double>(10, 10)],
        radius: 2,
        erase: false,
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(painted.left, lessThanOrEqualTo(8));
      expect(painted.top, lessThanOrEqualTo(8));
      expect(painted.containsImagePixel(10, 10), isTrue);
      // The original pixels survive the move.
      expect(painted.containsImagePixel(40, 40), isTrue);
    });

    test('erasing clears pixels without growing the bbox', () {
      final mask = filled(left: 0, top: 0, width: 40, height: 40);

      final erased = applyStrokeToMask(
        mask,
        const [math.Point<double>(20, 20)],
        radius: 4,
        erase: true,
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(erased.containsImagePixel(20, 20), isFalse);
      expect(erased.containsImagePixel(0, 0), isTrue);
      expect(erased.width, 40);
      expect(erased.height, 40);
    });

    test('clamps a stroke at the image edge', () {
      final painted = applyStrokeToMask(
        LeafMask.emptyAt(imageWidth: 20, imageHeight: 20),
        const [math.Point<double>(0, 0)],
        radius: 6,
        erase: false,
        imageWidth: 20,
        imageHeight: 20,
      );

      expect(painted.left, greaterThanOrEqualTo(0));
      expect(painted.top, greaterThanOrEqualTo(0));
      expect(painted.left + painted.width, lessThanOrEqualTo(20));
      expect(painted.containsImagePixel(0, 0), isTrue);
    });
  });

  group('fillMaskHoles', () {
    /// A [size]x[size] ring at ([left], [top]) with a hollow interior.
    LeafMask ring({int left = 0, int top = 0, int size = 9, int border = 2}) {
      final bytes = Uint8List(size * size);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final onBorder =
              x < border ||
              y < border ||
              x >= size - border ||
              y >= size - border;
          if (onBorder) bytes[y * size + x] = 1;
        }
      }
      return LeafMask(
        left: left,
        top: top,
        width: size,
        height: size,
        bytes: bytes,
      );
    }

    test('fills the hollow centre of a ring', () {
      final hollow = ring(left: 10, top: 20);
      expect(hollow.containsImagePixel(14, 24), isFalse);

      final solid = fillMaskHoles(hollow);

      expect(solid.containsImagePixel(14, 24), isTrue);
      expect(solid.pixelCount, 9 * 9);
      // The bbox is unchanged; only the interior was filled.
      expect(solid.left, 10);
      expect(solid.top, 20);
      expect(solid.width, 9);
    });

    test('leaves a notch that opens onto the border alone', () {
      final notched = ring(size: 9, border: 2);
      // Cut a channel from the hole out through the right edge.
      for (var x = 2; x < 9; x++) {
        notched.bytes[4 * 9 + x] = 0;
      }

      final filled = fillMaskHoles(notched);

      // The gap is reachable from outside, so it is a concave edge, not a hole.
      expect(filled.containsImagePixel(4, 4), isFalse);
      expect(filled.containsImagePixel(8, 4), isFalse);
    });

    test('treats a diagonally sealed gap as enclosed', () {
      // A 3x3 with only the four diagonal neighbours of the centre set leaves
      // the centre reachable only diagonally.
      final bytes = Uint8List(9);
      for (final i in [1, 3, 5, 7]) {
        bytes[i] = 1;
      }
      final mask = LeafMask(left: 0, top: 0, width: 3, height: 3, bytes: bytes);

      final filled = fillMaskHoles(mask);

      expect(filled.containsImagePixel(1, 1), isTrue);
    });

    test('tightens as it fills and copes with an empty mask', () {
      final loose = LeafMask(
        left: 0,
        top: 0,
        width: 10,
        height: 10,
        bytes: Uint8List(100),
      );
      loose.bytes[5 * 10 + 5] = 1;

      final filled = fillMaskHoles(loose);

      expect(filled.left, 5);
      expect(filled.top, 5);
      expect(filled.width, 1);
      expect(filled.height, 1);

      final empty = LeafMask(
        left: 3,
        top: 3,
        width: 4,
        height: 4,
        bytes: Uint8List(16),
      );
      expect(fillMaskHoles(empty).isEmpty, isTrue);
    });

    test('fills several separate holes at once', () {
      final bytes = Uint8List(11 * 11)..fillRange(0, 11 * 11, 1);
      bytes[2 * 11 + 2] = 0;
      bytes[8 * 11 + 8] = 0;
      bytes[5 * 11 + 2] = 0;
      final mask = LeafMask(
        left: 0,
        top: 0,
        width: 11,
        height: 11,
        bytes: bytes,
      );

      expect(fillMaskHoles(mask).pixelCount, 11 * 11);
    });
  });

  group('keepLargestRegion', () {
    /// Two solid blocks with a gap between them.
    LeafMask twoBlocks({int gap = 5}) {
      const height = 6;
      final width = 4 + gap + 8;
      final bytes = Uint8List(width * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < 4; x++) {
          bytes[y * width + x] = 1;
        }
        for (var x = 4 + gap; x < width; x++) {
          bytes[y * width + x] = 1;
        }
      }
      return LeafMask(
        left: 0,
        top: 0,
        width: width,
        height: height,
        bytes: bytes,
      );
    }

    test('drops the smaller of two detached pieces', () {
      final split = twoBlocks();

      final kept = keepLargestRegion(split);

      // Only the 8-wide block survives, and the bbox follows it.
      expect(kept.width, 8);
      expect(kept.height, 6);
      expect(kept.left, 9);
      expect(kept.pixelCount, 48);
    });

    test('leaves a single region untouched', () {
      final solid = LeafMask(
        left: 2,
        top: 3,
        width: 5,
        height: 5,
        bytes: Uint8List(25)..fillRange(0, 25, 1),
      );

      final kept = keepLargestRegion(solid);

      expect(kept.pixelCount, 25);
      expect(kept.left, 2);
      expect(kept.top, 3);
    });

    test('treats a corner touch as joined', () {
      // Two 2x2 blocks meeting only at a diagonal.
      final bytes = Uint8List(16);
      for (final i in [0, 1, 4, 5, 10, 11, 14, 15]) {
        bytes[i] = 1;
      }
      final mask = LeafMask(left: 0, top: 0, width: 4, height: 4, bytes: bytes);

      expect(keepLargestRegion(mask).pixelCount, 8);
    });

    test('copes with an empty mask', () {
      final empty = LeafMask(
        left: 1,
        top: 1,
        width: 4,
        height: 4,
        bytes: Uint8List(16),
      );

      expect(keepLargestRegion(empty).isEmpty, isTrue);
    });
  });

  group('lassoRegion', () {
    List<math.Point<double>> boxPath(double l, double t, double r, double b) =>
        [
          math.Point(l, t),
          math.Point(r, t),
          math.Point(r, b),
          math.Point(l, b),
          math.Point(l, t),
        ];

    test('encloses the box the path went round, whatever the nib', () {
      for (final radius in const [0, 4]) {
        final region = lassoRegion(
          boxPath(20, 20, 60, 60),
          radius: radius,
          imageWidth: 100,
          imageHeight: 100,
        );

        expect(region.containsImagePixel(40, 40), isTrue);
        expect(region.left, closeTo(20, 1), reason: 'radius $radius');
        expect(region.width, closeTo(41, 2), reason: 'radius $radius');
      }
    });

    test('joins the ends of a path that does not close', () {
      // Three sides of a box.
      final region = lassoRegion(
        const [
          math.Point(60.0, 20.0),
          math.Point(20.0, 20.0),
          math.Point(20.0, 60.0),
          math.Point(60.0, 60.0),
        ],
        radius: 0,
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(region.containsImagePixel(40, 40), isTrue);
      expect(region.containsImagePixel(58, 40), isTrue, reason: 'to the join');
    });

    test('a dot and a straight line enclose nothing', () {
      expect(
        lassoRegion(
          const [math.Point(50.0, 50.0)],
          radius: 0,
          imageWidth: 100,
          imageHeight: 100,
        ).isEmpty,
        isTrue,
      );
      expect(
        lassoRegion(
          const [math.Point(20.0, 50.0), math.Point(80.0, 50.0)],
          radius: 0,
          imageWidth: 100,
          imageHeight: 100,
        ).isEmpty,
        isTrue,
      );
    });

    test('a hairline path is continuous, so the loop seals', () {
      // Radius 0 has no disc to stamp, only the pixel under the nib, and the
      // samples along a fast drag are far apart.
      final region = lassoRegion(
        boxPath(10, 10, 90, 90),
        radius: 0,
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(region.containsImagePixel(50, 50), isTrue, reason: 'no leaks');
    });
  });

  group('growWithin', () {
    /// A 7x3 bar of two 3x3 blocks with a single column between them.
    LeafMask bar() {
      final bytes = Uint8List(7 * 3)..fillRange(0, 21, 1);
      return LeafMask(left: 0, top: 0, width: 7, height: 3, bytes: bytes);
    }

    test('grows the seed outward through the mask', () {
      final seed = filled(left: 0, top: 0, width: 1, height: 3);

      final grown = growWithin(seed, bar(), 2);

      expect(grown.containsImagePixel(2, 1), isTrue, reason: 'two steps out');
      expect(
        grown.containsImagePixel(3, 1),
        isFalse,
        reason: 'three is too far',
      );
    });

    test('stops at the edge of the mask it grows through', () {
      // Two blocks with a gap: nothing bridges it, however many steps.
      final bytes = Uint8List(7 * 3);
      for (var y = 0; y < 3; y++) {
        for (final x in const [0, 1, 2, 4, 5, 6]) {
          bytes[y * 7 + x] = 1;
        }
      }
      final split = LeafMask(
        left: 0,
        top: 0,
        width: 7,
        height: 3,
        bytes: bytes,
      );
      final seed = filled(left: 0, top: 0, width: 1, height: 3);

      final grown = growWithin(seed, split, 6);

      expect(grown.containsImagePixel(2, 1), isTrue, reason: 'its own block');
      expect(grown.containsImagePixel(3, 1), isFalse, reason: 'the gap');
      expect(grown.containsImagePixel(5, 1), isFalse, reason: 'across it');
    });

    test('clips the seed to the mask at zero steps', () {
      final seed = filled(left: 0, top: 0, width: 9, height: 3);

      final clipped = growWithin(seed, bar(), 0);

      expect(clipped.width, 7);
      expect(clipped.pixelCount, 21);
    });

    test('copes with an empty mask to grow through', () {
      final empty = LeafMask.emptyAt(imageWidth: 8, imageHeight: 8);

      expect(
        growWithin(
          filled(left: 0, top: 0, width: 2, height: 2),
          empty.tightened(),
          3,
        ).isEmpty,
        isTrue,
      );
    });
  });

  group('keepRegionAt', () {
    /// A 4-wide block at x 0..3 and an 8-wide block at x 9..16, both 6 tall.
    LeafMask twoBlocks() {
      const height = 6;
      const gap = 5;
      const width = 4 + gap + 8;
      final bytes = Uint8List(width * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < 4; x++) {
          bytes[y * width + x] = 1;
        }
        for (var x = 4 + gap; x < width; x++) {
          bytes[y * width + x] = 1;
        }
      }
      return LeafMask(
        left: 0,
        top: 0,
        width: width,
        height: height,
        bytes: bytes,
      );
    }

    test('keeps the seeded region even when it is the smaller one', () {
      final kept = keepRegionAt(twoBlocks(), const [math.Point(1, 3)]);

      expect(kept.left, 0);
      expect(kept.width, 4);
      expect(kept.containsImagePixel(1, 3), isTrue);
      expect(kept.containsImagePixel(12, 3), isFalse);
    });

    test('keeps the region the seeds cover most when they straddle two', () {
      final kept = keepRegionAt(twoBlocks(), const [
        math.Point(1, 3),
        math.Point(11, 3),
        math.Point(13, 3),
      ]);

      expect(kept.left, 9);
      expect(kept.width, 8);
    });

    test('falls back to the largest region when no seed lands on the mask', () {
      // Seeds in the gap belong to no region at all.
      final kept = keepRegionAt(twoBlocks(), const [math.Point(6, 3)]);

      expect(kept.left, 9);
      expect(kept.width, 8);
    });

    test('copes with an empty mask', () {
      final kept = keepRegionAt(
        LeafMask.emptyAt(imageWidth: 20, imageHeight: 20),
        const [math.Point(5, 5)],
      );

      expect(kept.isEmpty, isTrue);
    });
  });

  group('solidifyMaskAt', () {
    test('an outline drawn clear of the old shape fills and replaces it', () {
      // An existing solid leaf, plus a ring drawn well away from it.
      var mask = filled(left: 0, top: 0, width: 60, height: 60);
      mask = mask.expandedToInclude(
        const math.Rectangle<int>(0, 0, 200, 200),
        imageWidth: 200,
        imageHeight: 200,
      );
      final ring = <math.Point<double>>[];
      for (var angle = 0; angle < 360; angle += 5) {
        final radians = angle * math.pi / 180;
        ring.add(
          math.Point<double>(
            140 + 25 * math.cos(radians),
            140 + 25 * math.sin(radians),
          ),
        );
      }
      final painted = applyStrokeToMask(
        mask,
        ring,
        radius: 2,
        erase: false,
        imageWidth: 200,
        imageHeight: 200,
      );

      final solid = solidifyMaskAt(painted, ring);

      // The ring became a filled disc...
      expect(solid.containsImagePixel(140, 140), isTrue);
      // ...and the leaf it was drawn to replace is gone, despite being bigger.
      expect(solid.containsImagePixel(30, 30), isFalse);
    });
  });

  group('solidifyMask', () {
    test('joins a piece enclosed by another instead of discarding it', () {
      // A ring with a detached block floating inside it. The two are separate
      // regions, but the space between them is enclosed, so together they are
      // one leaf with a hole — filling must join them before anything is
      // dropped, or the inner block would be thrown away.
      const size = 9;
      final bytes = Uint8List(size * size);
      for (var i = 0; i < size; i++) {
        bytes[i] = 1;
        bytes[(size - 1) * size + i] = 1;
        bytes[i * size] = 1;
        bytes[i * size + size - 1] = 1;
      }
      for (var y = 3; y <= 5; y++) {
        for (var x = 3; x <= 5; x++) {
          bytes[y * size + x] = 1;
        }
      }

      final solid = solidifyMask(
        LeafMask(left: 0, top: 0, width: size, height: size, bytes: bytes),
      );

      expect(solid.pixelCount, size * size);
      expect(solid.containsImagePixel(4, 4), isTrue, reason: 'inner block');
      expect(solid.containsImagePixel(0, 4), isTrue, reason: 'ring');
    });

    test('yields one solid region from a holed, speckled mask', () {
      const width = 20, height = 12;
      final bytes = Uint8List(width * height);
      // A 10x10 blob with a pinhole, plus a detached speck.
      for (var y = 1; y < 11; y++) {
        for (var x = 1; x < 11; x++) {
          bytes[y * width + x] = 1;
        }
      }
      bytes[5 * width + 5] = 0;
      bytes[3 * width + 17] = 1;

      final solid = solidifyMask(
        LeafMask(left: 0, top: 0, width: width, height: height, bytes: bytes),
      );

      expect(solid.width, 10);
      expect(solid.height, 10);
      expect(solid.pixelCount, 100, reason: 'hole should be sealed');
      expect(solid.containsImagePixel(17, 3), isFalse, reason: 'speck dropped');
    });
  });

  group('hitTestMasks', () {
    test('returns the smallest mask so nested regions stay selectable', () {
      final big = filled(left: 0, top: 0, width: 50, height: 50);
      final small = filled(left: 10, top: 10, width: 5, height: 5);

      expect(hitTestMasks([big, small], 12, 12), 1);
      expect(hitTestMasks([big, small], 40, 40), 0);
      expect(hitTestMasks([big, small], 80, 80), isNull);
    });
  });

  group('composeOverlayRgba', () {
    test('paints mask pixels and leaves the rest transparent', () {
      final mask = filled(left: 0, top: 0, width: 50, height: 100);

      final rgba = composeOverlayRgba(
        masks: [mask],
        colors: const [0xFF0000],
        imageWidth: 100,
        imageHeight: 100,
        overlayWidth: 100,
        overlayHeight: 100,
      );

      // Inside the mask: red with partial alpha.
      const inside = (50 * 100 + 10) * 4;
      expect(rgba[inside], 255);
      expect(rgba[inside + 3], greaterThan(0));
      // Outside: untouched, fully transparent.
      const outside = (50 * 100 + 80) * 4;
      expect(rgba[outside + 3], 0);
    });

    test('downsamples to the requested overlay size', () {
      final rgba = composeOverlayRgba(
        masks: [filled(left: 0, top: 0, width: 1000, height: 1000)],
        colors: const [0x00FF00],
        imageWidth: 1000,
        imageHeight: 1000,
        overlayWidth: 100,
        overlayHeight: 100,
      );

      expect(rgba.length, 100 * 100 * 4);
      expect(rgba[3], greaterThan(0));
    });

    test('draws the selected mask more opaque than the others', () {
      final masks = [
        filled(left: 0, top: 0, width: 10, height: 10),
        filled(left: 20, top: 0, width: 10, height: 10),
      ];

      final rgba = composeOverlayRgba(
        masks: masks,
        colors: const [0xFF0000, 0x00FF00],
        selectedIndex: 1,
        imageWidth: 40,
        imageHeight: 10,
        overlayWidth: 40,
        overlayHeight: 10,
      );

      final unselectedAlpha = rgba[(0 * 40 + 5) * 4 + 3];
      final selectedAlpha = rgba[(0 * 40 + 25) * 4 + 3];
      expect(selectedAlpha, greaterThan(unselectedAlpha));
    });
  });
}
