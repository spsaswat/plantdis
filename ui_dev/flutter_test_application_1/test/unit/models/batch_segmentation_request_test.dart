import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';

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
}
