import 'dart:typed_data';

/// A rectangle whose coordinates are relative to the original image.
///
/// All values are in the inclusive range 0–1 so labels remain stable when the
/// image is rendered at a different size or processed on another device.
class NormalizedLabelRect {
  const NormalizedLabelRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  }) : assert(x >= 0 && x <= 1),
       assert(y >= 0 && y <= 1),
       assert(width >= 0 && width <= 1),
       assert(height >= 0 && height <= 1),
       assert(x + width <= 1.000001),
       assert(y + height <= 1.000001);

  factory NormalizedLabelRect.fromCorners({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
  }) {
    final clampedStartX = startX.clamp(0.0, 1.0);
    final clampedStartY = startY.clamp(0.0, 1.0);
    final clampedEndX = endX.clamp(0.0, 1.0);
    final clampedEndY = endY.clamp(0.0, 1.0);
    final left = clampedStartX < clampedEndX ? clampedStartX : clampedEndX;
    final top = clampedStartY < clampedEndY ? clampedStartY : clampedEndY;
    final right = clampedStartX > clampedEndX ? clampedStartX : clampedEndX;
    final bottom = clampedStartY > clampedEndY ? clampedStartY : clampedEndY;

    return NormalizedLabelRect(
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
  }

  factory NormalizedLabelRect.fromJson(Map<String, dynamic> json) {
    final x = (json['xMin'] ?? json['x']) as num;
    final y = (json['yMin'] ?? json['y']) as num;
    final width =
        json.containsKey('xMax')
            ? (json['xMax'] as num).toDouble() - x.toDouble()
            : (json['width'] as num).toDouble();
    final height =
        json.containsKey('yMax')
            ? (json['yMax'] as num).toDouble() - y.toDouble()
            : (json['height'] as num).toDouble();
    return NormalizedLabelRect(
      x: x.toDouble(),
      y: y.toDouble(),
      width: width,
      height: height,
    );
  }

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, double> toJson() => {
    'xMin': x,
    'yMin': y,
    'xMax': x + width,
    'yMax': y + height,
  };
}

/// Stable hand-off contract for the batch-processing flow implemented in #152.
class BatchSegmentationRequest {
  BatchSegmentationRequest({
    required this.imageId,
    required this.plantId,
    required this.imageUrl,
    required List<NormalizedLabelRect> labels,
    required this.localImageBytes,
    required this.imageWidth,
    required this.imageHeight,
  }) : labels = List.unmodifiable(labels);

  final String imageId;
  final String plantId;
  final String imageUrl;
  final List<NormalizedLabelRect> labels;
  final int imageWidth;
  final int imageHeight;

  /// Retained for an immediate desktop preview; deliberately omitted from
  /// [toJson] because #152 should use [imageId] to resolve the persisted image.
  final Uint8List localImageBytes;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'coordinateSpace': 'normalized_original_image',
    'imageId': imageId,
    'plantId': plantId,
    'imageUrl': imageUrl,
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'labels': [
      for (var index = 0; index < labels.length; index++)
        {'id': 'label_${index + 1}', ...labels[index].toJson()},
    ],
  };
}
