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
/// A leaf is one piece: an edit that pinches it in two leaves fragments that
/// are not part of the leaf. Regions are traced with 8-connectivity, so pixels
/// touching only at a corner still count as joined.
///
/// Like [applyStrokeToMask], this may write into [mask]'s buffer rather than
/// copying it.
LeafMask keepLargestRegion(LeafMask mask) => _keepOneRegion(mask, const []);

/// Reduces [mask] to the single connected region under [seeds] — the pixels a
/// paint stroke just laid down — discarding everything else.
///
/// This is what makes a stroke drawn clear of the current shape *replace* it
/// rather than be thrown away: the user is outlining a leaf, and the outline
/// they just drew is the one they mean. A stroke that touches the existing
/// shape merges with it instead, since the two are then one region, so
/// touching up an outline still works.
///
/// Falls back to [keepLargestRegion] when no seed lands on a set pixel.
LeafMask keepRegionAt(LeafMask mask, List<math.Point<double>> seeds) =>
    _keepOneRegion(mask, seeds);

/// Labels the regions of [mask] with 8-connectivity and keeps exactly one: the
/// region holding the most of [seeds], or the largest when [seeds] is empty or
/// lands entirely on background.
LeafMask _keepOneRegion(LeafMask mask, List<math.Point<double>> seeds) {
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

  // A stroke can cross more than one region; the one it covered most is the
  // one the user was drawing.
  var keptLabel = largestLabel;
  if (seeds.isNotEmpty) {
    final hits = <int, int>{};
    for (final seed in seeds) {
      final x = seed.x.floor() - tight.left;
      final y = seed.y.floor() - tight.top;
      if (x < 0 || x >= width || y < 0 || y >= height) continue;
      final label = labels[y * width + x];
      if (label == 0) continue;
      hits[label] = (hits[label] ?? 0) + 1;
    }
    if (hits.isNotEmpty) {
      keptLabel = hits.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    }
  }

  for (var i = 0; i < bytes.length; i++) {
    if (labels[i] != keptLabel) bytes[i] = 0;
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

/// [solidifyMask], but the region kept is the one under [seeds] rather than the
/// largest — see [keepRegionAt]. Holes are still sealed first, so an outline
/// drawn as a closed loop becomes a filled leaf.
LeafMask solidifyMaskAt(LeafMask mask, List<math.Point<double>> seeds) =>
    keepRegionAt(fillMaskHoles(mask), seeds);

/// Drops every pixel of [mask] that is not also set in [within].
///
/// Trims a drawn edge back to the leaf it resolved to, so a piece that
/// normalization threw away cannot reappear the next time the edge is filled.
LeafMask intersectMask(LeafMask mask, LeafMask within) {
  if (mask.width == 0 || mask.height == 0) return mask;
  final bytes = Uint8List.fromList(mask.bytes);
  for (var y = 0; y < mask.height; y++) {
    final row = y * mask.width;
    for (var x = 0; x < mask.width; x++) {
      if (bytes[row + x] == 0) continue;
      if (!within.containsImagePixel(mask.left + x, mask.top + y)) {
        bytes[row + x] = 0;
      }
    }
  }
  return LeafMask(
    left: mask.left,
    top: mask.top,
    width: mask.width,
    height: mask.height,
    bytes: bytes,
  ).tightened();
}

/// A pixel belonging to [mask], in full-image coordinates, or null when it is
/// empty.
///
/// An anchor for [keepRegionAt] that cannot miss: a stroke's own path points
/// can fall a pixel outside the region they enclose, at a corner the nib's
/// disc did not quite reach.
math.Point<double>? anyPixelIn(LeafMask mask) {
  for (var y = 0; y < mask.height; y++) {
    final row = y * mask.width;
    for (var x = 0; x < mask.width; x++) {
      if (mask.bytes[row + x] != 0) {
        return math.Point<double>(
          (mask.left + x).toDouble(),
          (mask.top + y).toDouble(),
        );
      }
    }
  }
  return null;
}

/// Every pixel set in either [mask] or [other].
LeafMask unionMask(LeafMask mask, LeafMask other) {
  // Copies, not the argument itself: the result goes on to be solidified,
  // which writes in place, and neither input is the caller's to lose.
  if (other.width == 0 || other.height == 0) return mask.deepCopy();
  if (mask.width == 0 || mask.height == 0) return other.deepCopy();
  final left = math.min(mask.left, other.left);
  final top = math.min(mask.top, other.top);
  final right = math.max(mask.left + mask.width, other.left + other.width);
  final bottom = math.max(mask.top + mask.height, other.top + other.height);
  final width = right - left;
  final height = bottom - top;
  final bytes = Uint8List(width * height);

  void blit(LeafMask from) {
    for (var y = 0; y < from.height; y++) {
      final dst = (from.top - top + y) * width + (from.left - left);
      final src = y * from.width;
      for (var x = 0; x < from.width; x++) {
        if (from.bytes[src + x] != 0) bytes[dst + x] = 1;
      }
    }
  }

  blit(mask);
  blit(other);
  return LeafMask(
    left: left,
    top: top,
    width: width,
    height: height,
    bytes: bytes,
  );
}

/// The region a lasso stroke through [imagePoints] encloses.
///
/// The line is a boundary, not paint. Its ends are joined when the path does
/// not already close, so a loop drawn by hand around a leaf encloses what it
/// went round even though it stopped short of its own start. The region
/// reaches the path the pen followed, whatever [radius] the nib is, so the
/// line contributes no width of its own. A path that encloses nothing even
/// once closed — a dot, or a straight line — gives an empty mask.
LeafMask lassoRegion(
  List<math.Point<double>> imagePoints, {
  required int radius,
  required int imageWidth,
  required int imageHeight,
}) {
  if (imagePoints.isEmpty) {
    return LeafMask(left: 0, top: 0, width: 0, height: 0, bytes: Uint8List(0));
  }

  // A buffer just big enough for the stroke. Joining the ends cannot leave it,
  // since both ends are already inside.
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final p in imagePoints) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  final pad = radius + 2;
  final left = math.max(0, (minX - pad).floor());
  final top = math.max(0, (minY - pad).floor());
  final right = math.min(imageWidth, (maxX + pad).ceil());
  final bottom = math.min(imageHeight, (maxY + pad).ceil());
  final width = math.max(0, right - left);
  final height = math.max(0, bottom - top);
  if (width == 0 || height == 0) {
    return LeafMask(left: 0, top: 0, width: 0, height: 0, bytes: Uint8List(0));
  }

  LeafMask stamp(LeafMask into, List<math.Point<double>> path) {
    return applyStrokeToMask(
      into,
      path,
      radius: radius,
      erase: false,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  LeafMask enclosedBy(LeafMask track) {
    final filled = solidifyMaskAt(track.deepCopy(), imagePoints);
    final enclosed = subtractMask(filled, track);
    // Bailing here is what keeps the retry below cheap: a path that encloses
    // nothing never reaches the dilation, so only the attempt that succeeds
    // pays for it.
    if (enclosed.isEmpty) return enclosed;
    // Grow the enclosed area back across the track that bounds it. The
    // distance is the track's half-width, so two things fall out: the cells a
    // self-crossing stroke cut the region into rejoin into one block, and the
    // edge lands on the path the pen followed rather than outside the nib.
    return keepLargestRegion(
      fillMaskHoles(growWithin(enclosed, filled, radius + 1)),
    );
  }

  var track = stamp(
    LeafMask(
      left: left,
      top: top,
      width: width,
      height: height,
      bytes: Uint8List(width * height),
    ),
    imagePoints,
  );
  var region = enclosedBy(track);
  if (region.isEmpty && imagePoints.length > 2) {
    track = stamp(track, [imagePoints.last, imagePoints.first]);
    region = enclosedBy(track);
  }
  return region;
}

/// Grows [seed] outward through [within], by at most [steps] pixels.
///
/// A dilation clipped to a mask, walked breadth-first rather than stamped: a
/// disc of radius r costs r squared neighbour tests on every set pixel, which
/// at a wide pen width runs to most of a second on a leaf-sized region. This
/// visits each pixel once instead, so the cost no longer grows with [steps].
///
/// Being confined to [within] also makes it the safer shape: the growth
/// follows the mask rather than reaching across a gap in it.
LeafMask growWithin(LeafMask seed, LeafMask within, int steps) {
  if (steps <= 0 || within.width == 0 || within.height == 0) {
    return intersectMask(seed, within);
  }
  final width = within.width;
  final height = within.height;
  final distance = Uint8List(width * height);
  final queue = <int>[];

  for (var y = 0; y < height; y++) {
    final row = y * width;
    for (var x = 0; x < width; x++) {
      if (within.bytes[row + x] == 0) continue;
      if (!seed.containsImagePixel(within.left + x, within.top + y)) continue;
      distance[row + x] = 1;
      queue.add(row + x);
    }
  }

  final limit = math.min(steps + 1, 255);
  for (var head = 0; head < queue.length; head++) {
    final index = queue[head];
    final step = distance[index];
    if (step >= limit) continue;
    final x = index % width;
    final y = index ~/ width;
    for (var dy = -1; dy <= 1; dy++) {
      final ny = y + dy;
      if (ny < 0 || ny >= height) continue;
      for (var dx = -1; dx <= 1; dx++) {
        final nx = x + dx;
        if (nx < 0 || nx >= width) continue;
        final neighbour = ny * width + nx;
        if (distance[neighbour] != 0 || within.bytes[neighbour] == 0) continue;
        distance[neighbour] = step + 1;
        queue.add(neighbour);
      }
    }
  }

  final bytes = Uint8List(width * height);
  for (var i = 0; i < bytes.length; i++) {
    if (distance[i] != 0) bytes[i] = 1;
  }
  return LeafMask(
    left: within.left,
    top: within.top,
    width: width,
    height: height,
    bytes: bytes,
  ).tightened();
}

/// Drops every pixel of [mask] that is also set in [without].
///
/// Takes a traced edge back out of the shape it encloses, leaving the enclosed
/// area on its own — the leaf, without the line drawn around it and without
/// whatever else that line trailed off into.
LeafMask subtractMask(LeafMask mask, LeafMask without) {
  if (mask.width == 0 || mask.height == 0) return mask;
  final bytes = Uint8List.fromList(mask.bytes);
  for (var y = 0; y < mask.height; y++) {
    final row = y * mask.width;
    for (var x = 0; x < mask.width; x++) {
      if (bytes[row + x] == 0) continue;
      if (without.containsImagePixel(mask.left + x, mask.top + y)) {
        bytes[row + x] = 0;
      }
    }
  }
  return LeafMask(
    left: mask.left,
    top: mask.top,
    width: mask.width,
    height: mask.height,
    bytes: bytes,
  ).tightened();
}

/// Rasterizes a pen stroke into [mask] and returns the updated mask.
///
/// [imagePoints] are full-image pixel coordinates. Discs of [radius] are
/// stamped along each segment; a [radius] of 0 draws a one-pixel line, which
/// is what tracing a leaf edge at high zoom needs. Paint strokes grow the
/// mask's bbox when they fall outside it; erase strokes only affect the
/// existing bbox.
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
    // +1 all round: the nib rounds to the nearest pixel, which can sit just
    // outside a bbox derived from the raw coordinates.
    final bounds = math.Rectangle<int>(
      (minX - radius).floor() - 1,
      (minY - radius).floor() - 1,
      (maxX - minX + 2 * radius).ceil() + 3,
      (maxY - minY + 2 * radius).ceil() + 3,
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

    // The pixel under the nib, always. A disc test alone misses it at radius
    // 0, where no pixel centre sits exactly on a fractional coordinate.
    final nibX = localCx.round();
    final nibY = localCy.round();
    if (nibX >= 0 && nibX < result.width && nibY >= 0 && nibY < result.height) {
      bytes[nibY * result.width + nibX] = value;
    }
    if (radius <= 0) return;

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
  // Half a pixel for a hairline, so a fast drag still draws a joined line.
  final step = math.max(0.5, radius / 2);
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
