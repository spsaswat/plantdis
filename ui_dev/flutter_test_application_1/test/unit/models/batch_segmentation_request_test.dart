import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/leaf_mask.dart';

LeafMask _mask({int left = 0, int top = 0, int size = 4}) {
  return LeafMask(
    left: left,
    top: top,
    width: size,
    height: size,
    bytes: Uint8List(size * size)..fillRange(0, size * size, 1),
  );
}

void main() {
  group('NormalizedLabelRect', () {
    test('normalizes reverse corners', () {
      final label = NormalizedLabelRect.fromCorners(
        startX: 0.8,
        startY: 0.7,
        endX: 0.2,
        endY: 0.1,
      );

      expect(label.x, closeTo(0.2, 0.0001));
      expect(label.y, closeTo(0.1, 0.0001));
      expect(label.width, closeTo(0.6, 0.0001));
      expect(label.height, closeTo(0.6, 0.0001));
    });

    test('clamps corners to the original image', () {
      final label = NormalizedLabelRect.fromCorners(
        startX: -0.2,
        startY: 0.25,
        endX: 1.4,
        endY: 2,
      );

      expect(label.toJson(), {
        'xMin': 0.0,
        'yMin': 0.25,
        'xMax': 1.0,
        'yMax': 1.0,
      });
    });

    test('clamps each endpoint before calculating the rectangle', () {
      final label = NormalizedLabelRect.fromCorners(
        startX: -0.2,
        startY: 0.25,
        endX: 0.2,
        endY: 0.5,
      );

      expect(label.toJson(), {
        'xMin': 0.0,
        'yMin': 0.25,
        'xMax': 0.2,
        'yMax': 0.5,
      });
    });

    test('reads canonical and legacy coordinate fields', () {
      final canonical = NormalizedLabelRect.fromJson({
        'xMin': 0.1,
        'yMin': 0.2,
        'xMax': 0.5,
        'yMax': 0.7,
      });
      final legacy = NormalizedLabelRect.fromJson({
        'x': 0.1,
        'y': 0.2,
        'width': 0.4,
        'height': 0.5,
      });

      expect(canonical.toJson(), legacy.toJson());
    });
  });

  test('batch request exposes the versioned #152 hand-off contract', () {
    const label = NormalizedLabelRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4);
    final request = BatchSegmentationRequest(
      imageId: 'image-1',
      plantId: 'plant-1',
      imageUrl: 'file:///image.jpg',
      labels: const [label],
      localImageBytes: Uint8List.fromList([1, 2, 3]),
      imageWidth: 4000,
      imageHeight: 3000,
    );

    expect(request.toJson(), {
      'schemaVersion': 1,
      'coordinateSpace': 'normalized_original_image',
      'imageId': 'image-1',
      'plantId': 'plant-1',
      'imageUrl': 'file:///image.jpg',
      'imageWidth': 4000,
      'imageHeight': 3000,
      'labels': [
        {
          'id': 'label_1',
          'xMin': 0.1,
          'yMin': 0.2,
          'xMax': 0.4,
          'yMax': 0.6000000000000001,
        },
      ],
    });
  });

  group('SAM masks', () {
    BatchSegmentationRequest build({List<LeafMask>? masks}) {
      return BatchSegmentationRequest(
        imageId: 'image-1',
        plantId: 'plant-1',
        imageUrl: 'file:///image.jpg',
        labels: const [
          NormalizedLabelRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
        ],
        localImageBytes: Uint8List.fromList([1, 2, 3]),
        imageWidth: 4000,
        imageHeight: 3000,
        masks: masks,
      );
    }

    test('a manual request carries no masks', () {
      final request = build();

      expect(request.hasMasks, isFalse);
      expect(request.masks, isNull);
      expect(request.toJson().containsKey('segmentationSource'), isFalse);
      expect(request.toJson().containsKey('maskCount'), isFalse);
    });

    test('records the source and count without serializing mask data', () {
      final json = build(masks: [_mask()]).toJson();

      expect(json['segmentationSource'], 'sam');
      expect(json['maskCount'], 1);
      // Mask pixels are processed locally and must never reach storage.
      expect(json.toString(), isNot(contains('bytes')));
      expect(json.values.whereType<Uint8List>(), isEmpty);
    });

    test('rejects masks that are not index-aligned with the labels', () {
      expect(() => build(masks: [_mask(), _mask()]), throwsA(isA<AssertionError>()));
    });
  });
}
