import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/utils/logger.dart';

/// Smallest usable crop edge, in source pixels. Regions below this are recorded
/// as failed entries instead of being fed to the classifiers, which upscale
/// everything to 224x224 and would otherwise produce noise from a few pixels.
const int kMinCropPixels = 16;

/// Decoded drone image plus whether it matched the labelling UI's dimensions.
class OrientedImage {
  const OrientedImage({required this.image, required this.dimensionsMatched});

  final img.Image image;

  /// False when the decoded size did not match the dimensions the labelling UI
  /// reported. Labels are still resolved against [image], but the mismatch is
  /// worth surfacing because it usually means EXIF orientation was handled
  /// differently on the two sides.
  final bool dimensionsMatched;

  int get width => image.width;
  int get height => image.height;
}

/// Decodes [bytes] and applies any EXIF orientation tag.
///
/// The labelling UI measures the image with `ui.instantiateImageCodec`, which
/// *applies* EXIF orientation; `img.decodeImage` does not. Drone JPEGs commonly
/// carry an orientation tag, so without [img.bakeOrientation] the crops would be
/// taken from a differently-oriented buffer than the one the user drew on.
///
/// When [expectedWidth] / [expectedHeight] are supplied they are compared
/// against the decoded result and a mismatch is logged. Labels are always
/// resolved against the decoded dimensions so crops stay inside the buffer.
OrientedImage decodeOriented(
  Uint8List bytes, {
  int? expectedWidth,
  int? expectedHeight,
}) {
  // decodeImage returns null for some malformed input but throws (RangeError,
  // among others) for the rest, so normalise both into a FormatException.
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (e) {
    throw FormatException('Could not decode the drone image: $e');
  }
  if (decoded == null) {
    throw const FormatException('Could not decode the drone image');
  }
  final oriented = img.bakeOrientation(decoded);

  var matched = true;
  if (expectedWidth != null && expectedHeight != null) {
    matched =
        oriented.width == expectedWidth && oriented.height == expectedHeight;
    if (!matched) {
      logger.w(
        '[analysis_utils] Decoded image is ${oriented.width}x${oriented.height} '
        'but the labels were drawn against ${expectedWidth}x$expectedHeight. '
        'Resolving labels against the decoded size.',
      );
    }
  }

  return OrientedImage(image: oriented, dimensionsMatched: matched);
}

/// Converts a normalized label into source pixels, clamped to the image bounds.
///
/// The result is always inside `0..imageWidth` / `0..imageHeight`, but it can
/// still be degenerate for a rect drawn at the very edge of the image — check
/// [isUsableCrop] before cropping.
math.Rectangle<int> denormalizeRect(
  NormalizedLabelRect rect,
  int imageWidth,
  int imageHeight,
) {
  final left = (rect.x * imageWidth).floor().clamp(0, imageWidth);
  final top = (rect.y * imageHeight).floor().clamp(0, imageHeight);
  final right = ((rect.x + rect.width) * imageWidth).ceil().clamp(0, imageWidth);
  final bottom =
      ((rect.y + rect.height) * imageHeight).ceil().clamp(0, imageHeight);

  return math.Rectangle<int>(left, top, right - left, bottom - top);
}

/// Whether [rect] is large enough to be worth running the models on.
bool isUsableCrop(math.Rectangle<int> rect) {
  return rect.width >= kMinCropPixels && rect.height >= kMinCropPixels;
}

/// Crops [rect] out of [source] and encodes it as JPEG.
///
/// [source] is not modified, so the same decoded image can be reused for every
/// region in a batch — important because a decoded 20 MP drone frame is roughly
/// 80 MB and decoding it per leaf would be both slow and memory-hungry.
Uint8List cropLeafJpeg(
  img.Image source,
  math.Rectangle<int> rect, {
  int quality = 90,
}) {
  final cropped = img.copyCrop(
    source,
    x: rect.left,
    y: rect.top,
    width: rect.width,
    height: rect.height,
  );
  return img.encodeJpg(cropped, quality: quality);
}
