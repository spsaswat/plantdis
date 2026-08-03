import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
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
}
