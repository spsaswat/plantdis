import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/utils/analysis_utils.dart';

void main() {
  group('denormalizeRect', () {
    test('converts a normalized label into source pixels', () {
      const label = NormalizedLabelRect(
        x: 0.25,
        y: 0.5,
        width: 0.25,
        height: 0.25,
      );

      final rect = denormalizeRect(label, 4000, 3000);

      expect(rect.left, 1000);
      expect(rect.top, 1500);
      expect(rect.width, 1000);
      expect(rect.height, 750);
    });

    test('clamps a full-image label to the image bounds', () {
      const label = NormalizedLabelRect(x: 0, y: 0, width: 1, height: 1);

      final rect = denormalizeRect(label, 640, 480);

      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.width, 640);
      expect(rect.height, 480);
    });

    test('never runs past the right or bottom edge', () {
      // Rounding out with ceil() must not push the crop outside the buffer.
      const label = NormalizedLabelRect(
        x: 0.9999,
        y: 0.9999,
        width: 0.0001,
        height: 0.0001,
      );

      final rect = denormalizeRect(label, 100, 100);

      expect(rect.left + rect.width, lessThanOrEqualTo(100));
      expect(rect.top + rect.height, lessThanOrEqualTo(100));
    });
  });

  group('isUsableCrop', () {
    test('rejects a region smaller than the minimum on either axis', () {
      // 0.001 of 4000px is 4px wide — far too small for a 224x224 classifier.
      const tiny = NormalizedLabelRect(
        x: 0.1,
        y: 0.1,
        width: 0.001,
        height: 0.5,
      );

      expect(isUsableCrop(denormalizeRect(tiny, 4000, 3000)), isFalse);
    });

    test('accepts a region at least kMinCropPixels on both axes', () {
      const ok = NormalizedLabelRect(x: 0.1, y: 0.1, width: 0.1, height: 0.1);

      expect(isUsableCrop(denormalizeRect(ok, 4000, 3000)), isTrue);
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

  group('cropLeafJpeg', () {
    test('produces a decodable JPEG of the requested size', () {
      final source = img.Image(width: 200, height: 100);
      const label = NormalizedLabelRect(
        x: 0.25,
        y: 0.0,
        width: 0.5,
        height: 0.5,
      );
      final rect = denormalizeRect(label, source.width, source.height);

      final jpeg = cropLeafJpeg(source, rect);
      final decoded = img.decodeJpg(jpeg);

      expect(decoded, isNotNull);
      expect(decoded!.width, rect.width);
      expect(decoded.height, rect.height);
    });

    test('leaves the source image untouched so it can be reused', () {
      final source = img.Image(width: 200, height: 100);
      final rect = denormalizeRect(
        const NormalizedLabelRect(x: 0, y: 0, width: 0.5, height: 0.5),
        source.width,
        source.height,
      );

      cropLeafJpeg(source, rect);

      expect(source.width, 200);
      expect(source.height, 100);
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
