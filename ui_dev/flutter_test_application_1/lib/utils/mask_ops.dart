import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test_application_1/models/leaf_mask.dart';

/// Pure raster operations for editing and displaying [LeafMask]s. Kept free of
/// `dart:ui` so everything here is unit-testable and reusable by a future
/// mask-based manual labelling flow.

/// Fills enclosed background regions so the mask reads as one solid leaf.
///
/// A leaf is a continuous surface: gaps inside it are artefacts, whether they
/// come from SAM missing a vein or a highlight, or from a brush stroke that
/// looped back on itself. Background is flooded inward from the bounding-box
/// border with 4-connectivity; anything the flood cannot reach is enclosed and
/// gets filled. Using 4-connectivity for the background means a gap sealed only
/// diagonally still counts as enclosed, which matches how the foreground reads
/// to the eye.
///
/// The result is tightened first, since a hole can only exist inside the tight
/// bounding box. Like [applyStrokeToMask], this may write into [mask]'s buffer
/// rather than copying it.
LeafMask fillMaskHoles(LeafMask mask) {
  final tight = mask.tightened();
  final width = tight.width;
  final height = tight.height;
  if (width == 0 || height == 0) return tight;

  final bytes = tight.bytes;
  // Marks background pixels the flood has reached from outside. Foreground
  // pixels are never queued, so they stay 0 here and are skipped below.
  final reached = Uint8List(width * height);
  final stack = <int>[];

  void push(int index) {
    if (bytes[index] == 0 && reached[index] == 0) {
      reached[index] = 1;
      stack.add(index);
    }
  }

  // Everything outside the bbox is background, so the whole border is exterior.
  for (var x = 0; x < width; x++) {
    push(x);
    push((height - 1) * width + x);
  }
  for (var y = 0; y < height; y++) {
    push(y * width);
    push(y * width + width - 1);
  }

  while (stack.isNotEmpty) {
    final index = stack.removeLast();
    final x = index % width;
    if (x > 0) push(index - 1);
    if (x < width - 1) push(index + 1);
    if (index >= width) push(index - width);
    if (index < bytes.length - width) push(index + width);
  }

  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] == 0 && reached[i] == 0) bytes[i] = 1;
  }

  // A fresh wrapper so the lazily cached pixel count reflects the fill.
  return LeafMask(
    left: tight.left,
    top: tight.top,
    width: width,
    height: height,
    bytes: bytes,
  );
}

/// Reduces [mask] to its largest connected region, discarding detached pieces.
///
/// A leaf is one piece: an edit that pinches it in two, or a dab of paint that
/// lands clear of the rest, leaves fragments that are not part of the leaf.
/// Regions are traced with 8-connectivity, so pixels touching only at a corner
/// still count as joined.
///
/// Like [applyStrokeToMask], this may write into [mask]'s buffer rather than
/// copying it.
LeafMask keepLargestRegion(LeafMask mask) {
  final tight = mask.tightened();
  final width = tight.width;
  final height = tight.height;
  if (width == 0 || height == 0) return tight;

  final bytes = tight.bytes;
  final labels = Uint32List(width * height);
  final stack = <int>[];
  var regionCount = 0;
  var largestLabel = 0;
  var largestSize = 0;

  for (var start = 0; start < bytes.length; start++) {
    if (bytes[start] == 0 || labels[start] != 0) continue;

    final label = ++regionCount;
    var size = 0;
    labels[start] = label;
    stack.add(start);

    while (stack.isNotEmpty) {
      final index = stack.removeLast();
      size++;
      final x = index % width;
      final y = index ~/ width;
      for (var dy = -1; dy <= 1; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= height) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx;
          if (nx < 0 || nx >= width) continue;
          final neighbour = ny * width + nx;
          if (bytes[neighbour] != 0 && labels[neighbour] == 0) {
            labels[neighbour] = label;
            stack.add(neighbour);
          }
        }
      }
    }

    if (size > largestSize) {
      largestSize = size;
      largestLabel = label;
    }
  }

  if (regionCount <= 1) return tight;

  for (var i = 0; i < bytes.length; i++) {
    if (labels[i] != largestLabel) bytes[i] = 0;
  }
  return LeafMask(
    left: tight.left,
    top: tight.top,
    width: width,
    height: height,
    bytes: bytes,
  ).tightened();
}

/// Makes [mask] describe a single leaf: one continuous region, no gaps inside.
///
/// Holes are sealed first. That matters, because two pieces that jointly
/// enclose a gap are really one leaf with a hole in it, and filling joins them
/// rather than throwing one away. Dropping detached regions afterwards cannot
/// reopen a hole, since a filled mask has no region nested inside another.
LeafMask solidifyMask(LeafMask mask) => keepLargestRegion(fillMaskHoles(mask));

/// Rasterizes a brush stroke into [mask] and returns the updated mask.
///
/// [imagePoints] are full-image pixel coordinates. Discs of [radius] are
/// stamped along each segment. Paint strokes grow the mask's bbox when they
/// fall outside it; erase strokes only affect the existing bbox.
///
/// Writes into [mask]'s buffer in place when the bbox does not have to grow —
/// copying a full-frame buffer on every stroke of a 20 MP image would be far
/// too slow. Snapshot with [LeafMask.deepCopy] first if you need the previous
/// state, as the editor does for undo.
LeafMask applyStrokeToMask(
  LeafMask mask,
  List<math.Point<double>> imagePoints, {
  required int radius,
  required bool erase,
  required int imageWidth,
  required int imageHeight,
}) {
  if (imagePoints.isEmpty) return mask;

  var result = mask;
  if (!erase) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in imagePoints) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
    final bounds = math.Rectangle<int>(
      (minX - radius).floor(),
      (minY - radius).floor(),
      (maxX - minX + 2 * radius).ceil() + 1,
      (maxY - minY + 2 * radius).ceil() + 1,
    );
    result = result.expandedToInclude(
      bounds,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }
  if (result.width == 0 || result.height == 0) return result;

  final bytes = result.bytes;
  final value = erase ? 0 : 1;

  void stampDisc(double cx, double cy) {
    final localCx = cx - result.left;
    final localCy = cy - result.top;
    final x0 = math.max(0, (localCx - radius).floor());
    final x1 = math.min(result.width - 1, (localCx + radius).ceil());
    final y0 = math.max(0, (localCy - radius).floor());
    final y1 = math.min(result.height - 1, (localCy + radius).ceil());
    final r2 = radius * radius;
    for (var y = y0; y <= y1; y++) {
      final dy = y - localCy;
      final row = y * result.width;
      for (var x = x0; x <= x1; x++) {
        final dx = x - localCx;
        if (dx * dx + dy * dy <= r2) bytes[row + x] = value;
      }
    }
  }

  stampDisc(imagePoints.first.x, imagePoints.first.y);
  final step = math.max(1.0, radius / 2);
  for (var i = 1; i < imagePoints.length; i++) {
    final a = imagePoints[i - 1];
    final b = imagePoints[i];
    final distance = a.distanceTo(b);
    final steps = math.max(1, (distance / step).ceil());
    for (var s = 1; s <= steps; s++) {
      final t = s / steps;
      stampDisc(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
    }
  }

  // A fresh wrapper over the same buffer, so lazily cached counts recompute.
  return LeafMask(
    left: result.left,
    top: result.top,
    width: result.width,
    height: result.height,
    bytes: bytes,
  );
}

/// Builds a straight-alpha RGBA overlay of all masks at
/// [overlayWidth]×[overlayHeight] (nearest-neighbour sampled from the
/// full-resolution masks). [colors] are 0xRRGGBB, one per mask; the selected
/// mask is drawn last and more opaque so it reads on top.
Uint8List composeOverlayRgba({
  required List<LeafMask> masks,
  required List<int> colors,
  int? selectedIndex,
  required int imageWidth,
  required int imageHeight,
  required int overlayWidth,
  required int overlayHeight,
}) {
  assert(colors.length == masks.length);
  final out = Uint8List(overlayWidth * overlayHeight * 4);
  final scaleX = imageWidth / overlayWidth;
  final scaleY = imageHeight / overlayHeight;

  void drawMask(int index, int alpha) {
    final mask = masks[index];
    if (mask.width == 0 || mask.height == 0) return;
    final color = colors[index];
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;

    // Only walk the overlay pixels covering the mask's bbox.
    final oy0 = math.max(0, (mask.top / scaleY).floor());
    final oy1 = math.min(
      overlayHeight - 1,
      ((mask.top + mask.height) / scaleY).ceil(),
    );
    final ox0 = math.max(0, (mask.left / scaleX).floor());
    final ox1 = math.min(
      overlayWidth - 1,
      ((mask.left + mask.width) / scaleX).ceil(),
    );
    for (var oy = oy0; oy <= oy1; oy++) {
      final iy = (oy * scaleY).floor();
      for (var ox = ox0; ox <= ox1; ox++) {
        final ix = (ox * scaleX).floor();
        if (mask.containsImagePixel(ix, iy)) {
          final o = (oy * overlayWidth + ox) * 4;
          out[o] = r;
          out[o + 1] = g;
          out[o + 2] = b;
          out[o + 3] = alpha;
        }
      }
    }
  }

  for (var i = 0; i < masks.length; i++) {
    if (i == selectedIndex) continue;
    drawMask(i, 102); // ~40%
  }
  if (selectedIndex != null &&
      selectedIndex >= 0 &&
      selectedIndex < masks.length) {
    drawMask(selectedIndex, 166); // ~65%
  }
  return out;
}

/// Index of the smallest mask containing the full-image pixel ([x], [y]), or
/// null. Smallest-first keeps nested and overlapping masks selectable.
int? hitTestMasks(List<LeafMask> masks, int x, int y) {
  int? best;
  var bestArea = 1 << 62;
  for (var i = 0; i < masks.length; i++) {
    if (masks[i].containsImagePixel(x, y)) {
      final area = masks[i].pixelCount;
      if (area < bestArea) {
        bestArea = area;
        best = i;
      }
    }
  }
  return best;
}
