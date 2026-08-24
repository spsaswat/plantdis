import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/utils/analysis_utils.dart';

void main() {
  group('isUsableCrop', () {
    test('rejects a region smaller than the minimum on either axis', () {
      // 4px wide is far too small for a 224x224 classifier.
      expect(isUsableCrop(const math.Rectangle<int>(10, 10, 4, 1500)), isFalse);
      expect(isUsableCrop(const math.Rectangle<int>(10, 10, 1500, 4)), isFalse);
    });

    test('accepts a region at least kMinCropPixels on both axes', () {
      expect(
        isUsableCrop(
          const math.Rectangle<int>(10, 10, kMinCropPixels, kMinCropPixels),
        ),
        isTrue,
      );
    });
  });

  group('decodeOriented', () {
    test('reports a mismatch against the declared dimensions', () {
      final bytes = img.encodeJpg(img.Image(width: 120, height: 80));

      final matching = decodeOriented(
        bytes,
        expectedWidth: 120,
        expectedHeight: 80,
      );
      expect(matching.dimensionsMatched, isTrue);
      expect(matching.width, 120);
      expect(matching.height, 80);

      // Swapped dimensions are what an unhandled EXIF rotation looks like.
      final mismatched = decodeOriented(
        bytes,
        expectedWidth: 80,
        expectedHeight: 120,
      );
      expect(mismatched.dimensionsMatched, isFalse);
      // Labels still resolve against the decoded size so crops stay in bounds.
      expect(mismatched.width, 120);
      expect(mismatched.height, 80);
    });

    test('throws on bytes that are not an image', () {
      expect(
        () => decodeOriented(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('clampRectToImage', () {
    test('trims a rect that overhangs the image', () {
      final clamped = clampRectToImage(
        const math.Rectangle<int>(-10, -5, 50, 40),
        30,
        20,
      );

      expect(clamped.left, 0);
      expect(clamped.top, 0);
      expect(clamped.width, 30);
      expect(clamped.height, 20);
    });

    test('leaves an inside rect alone', () {
      final clamped = clampRectToImage(
        const math.Rectangle<int>(5, 5, 10, 10),
        100,
        100,
      );

      expect(clamped, const math.Rectangle<int>(5, 5, 10, 10));
    });
  });

  group('maskedLeafJpeg', () {
    /// A solid green image with a mask covering the left half of a 8x8 bbox
    /// at (2, 2).
    (img.Image, LeafMask) fixture() {
      final source = img.Image(width: 16, height: 16);
      img.fill(source, color: img.ColorRgb8(0, 255, 0));
      final bytes = Uint8List(8 * 8);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 4; x++) {
          bytes[y * 8 + x] = 1;
        }
      }
      return (
        source,
        LeafMask(left: 2, top: 2, width: 8, height: 8, bytes: bytes),
      );
    }

    test('crops to the bbox and blacks out non-mask pixels', () {
      final (source, mask) = fixture();

      final decoded = img.decodeJpg(maskedLeafJpeg(source, mask))!;

      expect(decoded.width, 8);
      expect(decoded.height, 8);
      // Inside the mask the leaf colour survives (JPEG is lossy, so allow
      // some slack).
      final kept = decoded.getPixel(1, 4);
      expect(kept.g, greaterThan(200));
      // Outside it the background is black.
      final blacked = decoded.getPixel(6, 4);
      expect(blacked.r, lessThan(40));
      expect(blacked.g, lessThan(40));
      expect(blacked.b, lessThan(40));
    });

    test('leaves the source image untouched so it can be reused', () {
      final (source, mask) = fixture();

      maskedLeafJpeg(source, mask);

      expect(source.width, 16);
      expect(source.getPixel(6, 4).g, 255);
    });

    test('clamps a mask that overhangs the image', () {
      final source = img.Image(width: 16, height: 16);
      img.fill(source, color: img.ColorRgb8(0, 255, 0));
      final mask = LeafMask(
        left: 12,
        top: 12,
        width: 8,
        height: 8,
        bytes: Uint8List(64)..fillRange(0, 64, 1),
      );

      final decoded = img.decodeJpg(maskedLeafJpeg(source, mask))!;

      expect(decoded.width, 4);
      expect(decoded.height, 4);
    });
  });
}
