import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';

/// A binary leaf mask stored as a tight bounding-box crop.
///
/// Coordinates are pixels in the full-resolution *oriented* drone image (the
/// same space `decodeOriented` produces), so a mask can be applied directly to
/// the decoded frame without any rescaling. Only the bbox interior is stored —
/// one byte per pixel, 1 = leaf — which keeps a typical mask at a few hundred
/// KB instead of a full 20 MP frame.
class LeafMask {
  LeafMask({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.bytes,
  }) : assert(left >= 0),
       assert(top >= 0),
       assert(width >= 0),
       assert(height >= 0),
       assert(bytes.length == width * height);

  /// An all-zero mask covering the whole image, for "Add mask" in the editor.
  ///
  /// The bbox intentionally spans the full frame so the first paint stroke
  /// never needs an expansion; [tightened] shrinks it when the mask is final.
  factory LeafMask.emptyAt({required int imageWidth, required int imageHeight}) {
    return LeafMask(
      left: 0,
      top: 0,
      width: imageWidth,
      height: imageHeight,
      bytes: Uint8List(imageWidth * imageHeight),
    );
  }

  final int left;
  final int top;
  final int width;
  final int height;

  /// Row-major `width * height` bytes, each 0 or 1.
  final Uint8List bytes;

  math.Rectangle<int> get bbox => math.Rectangle<int>(left, top, width, height);

  int? _pixelCount;

  /// Number of set pixels. Computed lazily; treat the mask as immutable once
  /// this has been read.
  int get pixelCount {
    final cached = _pixelCount;
    if (cached != null) return cached;
    var count = 0;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != 0) count++;
    }
    return _pixelCount = count;
  }

  bool get isEmpty => pixelCount == 0;

  /// Whether the full-image pixel ([x], [y]) belongs to this mask.
  bool containsImagePixel(int x, int y) {
    final localX = x - left;
    final localY = y - top;
    if (localX < 0 || localX >= width || localY < 0 || localY >= height) {
      return false;
    }
    return bytes[localY * width + localX] != 0;
  }

  /// The bbox as a normalized rect, the shape every existing batch consumer
  /// (Firestore records, region overlays) expects.
  NormalizedLabelRect toNormalizedRect(int imageWidth, int imageHeight) {
    return NormalizedLabelRect.fromCorners(
      startX: left / imageWidth,
      startY: top / imageHeight,
      endX: (left + width) / imageWidth,
      endY: (top + height) / imageHeight,
    );
  }

  /// Returns a mask whose bbox additionally covers [region] (clamped to the
  /// image), with the existing bytes copied at the right offset.
  LeafMask expandedToInclude(
    math.Rectangle<int> region, {
    required int imageWidth,
    required int imageHeight,
  }) {
    final newLeft = math.min(left, region.left.clamp(0, imageWidth));
    final newTop = math.min(top, region.top.clamp(0, imageHeight));
    final newRight = math.max(
      left + width,
      (region.left + region.width).clamp(0, imageWidth),
    );
    final newBottom = math.max(
      top + height,
      (region.top + region.height).clamp(0, imageHeight),
    );
    final newWidth = newRight - newLeft;
    final newHeight = newBottom - newTop;
    if (newLeft == left &&
        newTop == top &&
        newWidth == width &&
        newHeight == height) {
      return this;
    }

    final newBytes = Uint8List(newWidth * newHeight);
    final dx = left - newLeft;
    final dy = top - newTop;
    for (var y = 0; y < height; y++) {
      newBytes.setRange(
        (y + dy) * newWidth + dx,
        (y + dy) * newWidth + dx + width,
        bytes,
        y * width,
      );
    }
    return LeafMask(
      left: newLeft,
      top: newTop,
      width: newWidth,
      height: newHeight,
      bytes: newBytes,
    );
  }

  /// Recomputes the tight bbox — needed after erasing. Returns a zero-size
  /// mask when nothing is set.
  LeafMask tightened() {
    var minX = width, minY = height, maxX = -1, maxY = -1;
    for (var y = 0; y < height; y++) {
      final row = y * width;
      for (var x = 0; x < width; x++) {
        if (bytes[row + x] != 0) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) {
      return LeafMask(left: left, top: top, width: 0, height: 0, bytes: Uint8List(0));
    }
    final newWidth = maxX - minX + 1;
    final newHeight = maxY - minY + 1;
    if (minX == 0 && minY == 0 && newWidth == width && newHeight == height) {
      return this;
    }
    final newBytes = Uint8List(newWidth * newHeight);
    for (var y = 0; y < newHeight; y++) {
      newBytes.setRange(
        y * newWidth,
        y * newWidth + newWidth,
        bytes,
        (y + minY) * width + minX,
      );
    }
    return LeafMask(
      left: left + minX,
      top: top + minY,
      width: newWidth,
      height: newHeight,
      bytes: newBytes,
    );
  }

  LeafMask deepCopy() {
    return LeafMask(
      left: left,
      top: top,
      width: width,
      height: height,
      bytes: Uint8List.fromList(bytes),
    );
  }
}
