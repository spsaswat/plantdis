import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test_application_1/models/leaf_mask.dart';

/// Pure post-processing for the tiled leaf Mask R-CNN. Kept free of the ONNX
/// runtime and `dart:ui` so it is unit-testable against torchvision's output.

/// Start offsets of [tile]-sized windows covering [length] with [stride].
///
/// The last window is pinned to the far edge, so every window is full-size
/// whenever [length] >= [tile] — the size the model was trained on.
List<int> tileStarts(int length, int tile, int stride) {
  final last = math.max(length - tile, 0);
  final starts = <int>[for (var s = 0; s <= last; s += stride) s];
  if (starts.last != last) starts.add(last);
  return starts;
}

/// Whether a detection box hugs a tile edge that is not also an image edge.
///
/// Such a leaf is probably cut off by the tile; a neighbouring tile overlaps
/// this one and is expected to see it whole.
bool touchesInnerTileEdge({
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required int tileLeft,
  required int tileTop,
  required int tileWidth,
  required int tileHeight,
  required int imageWidth,
  required int imageHeight,
  double margin = 4,
}) {
  return (x0 < margin && tileLeft > 0) ||
      (y0 < margin && tileTop > 0) ||
      (x1 > tileWidth - margin && tileLeft + tileWidth < imageWidth) ||
      (y1 > tileHeight - margin && tileTop + tileHeight < imageHeight);
}

/// Pastes one `maskSize`×`maskSize` Mask R-CNN probability map into its box,
/// exactly as torchvision's `paste_masks_in_image` does (1 px zero padding,
/// expanded int box, bilinear resize with `align_corners=False`), then
/// thresholds it.
///
/// The box is in tile pixels; the result is a tight [LeafMask] in image pixels,
/// shifted by ([offsetX], [offsetY]). Returns null when nothing survives.
LeafMask? pasteMaskRcnnMask({
  required Float32List probs,
  required int maskSize,
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required int tileWidth,
  required int tileHeight,
  int offsetX = 0,
  int offsetY = 0,
  double threshold = 0.5,
}) {
  final m = maskSize;
  final padded = m + 2;
  final scale = padded / m;

  // expand_boxes, then .to(int64), which truncates toward zero.
  final halfW = (x1 - x0) * 0.5 * scale;
  final halfH = (y1 - y0) * 0.5 * scale;
  final cx = (x1 + x0) * 0.5;
  final cy = (y1 + y0) * 0.5;
  final bx0 = (cx - halfW).toInt();
  final by0 = (cy - halfH).toInt();
  final bx1 = (cx + halfW).toInt();
  final by1 = (cy + halfH).toInt();
  final w = math.max(bx1 - bx0 + 1, 1);
  final h = math.max(by1 - by0 + 1, 1);

  final left = math.max(bx0, 0);
  final right = math.min(bx1 + 1, tileWidth);
  final top = math.max(by0, 0);
  final bottom = math.min(by1 + 1, tileHeight);
  if (right <= left || bottom <= top) return null;

  // Bilinear source indices into the zero-padded map, per output column/row.
  double padValue(int px, int py) {
    if (px == 0 || py == 0 || px == padded - 1 || py == padded - 1) return 0;
    return probs[(py - 1) * m + (px - 1)];
  }

  final cols = right - left;
  final colLo = Int32List(cols);
  final colHi = Int32List(cols);
  final colT = Float64List(cols);
  for (var i = 0; i < cols; i++) {
    final src = math.max((left - bx0 + i + 0.5) * padded / w - 0.5, 0.0);
    final lo = src.toInt();
    colLo[i] = lo;
    colHi[i] = lo < padded - 1 ? lo + 1 : lo;
    colT[i] = src - lo;
  }

  final rows = bottom - top;
  final out = Uint8List(cols * rows);
  var minX = cols, minY = rows, maxX = -1, maxY = -1;
  for (var j = 0; j < rows; j++) {
    final src = math.max((top - by0 + j + 0.5) * padded / h - 0.5, 0.0);
    final lo = src.toInt();
    final hi = lo < padded - 1 ? lo + 1 : lo;
    final t = src - lo;
    for (var i = 0; i < cols; i++) {
      final a = padValue(colLo[i], lo);
      final b = padValue(colHi[i], lo);
      final c = padValue(colLo[i], hi);
      final d = padValue(colHi[i], hi);
      final s = colT[i];
      final v = (1 - t) * ((1 - s) * a + s * b) + t * ((1 - s) * c + s * d);
      if (v > threshold) {
        out[j * cols + i] = 1;
        if (i < minX) minX = i;
        if (i > maxX) maxX = i;
        if (j < minY) minY = j;
        if (j > maxY) maxY = j;
      }
    }
  }
  if (maxX < 0) return null;

  final tw = maxX - minX + 1;
  final th = maxY - minY + 1;
  final tight = Uint8List(tw * th);
  for (var j = 0; j < th; j++) {
    final src = (minY + j) * cols + minX;
    tight.setRange(j * tw, (j + 1) * tw, out, src);
  }
  return LeafMask(
    left: offsetX + left + minX,
    top: offsetY + top + minY,
    width: tw,
    height: th,
    bytes: tight,
  );
}

/// One leaf found in one tile.
class LeafDetection {
  const LeafDetection({
    required this.mask,
    required this.score,
    this.cutByTileEdge = false,
  });

  final LeafMask mask;
  final double score;

  /// See [touchesInnerTileEdge]. Kept as a fallback for leaves too big to fit
  /// whole in any tile.
  final bool cutByTileEdge;
}

/// Overlapping pixels of [a] and [b] divided by the smaller mask's area.
///
/// Dividing by the smaller area (not the union) also catches a partial copy of
/// a leaf seen by a neighbouring tile.
double maskOverlapRatio(LeafMask a, LeafMask b) {
  final left = math.max(a.left, b.left);
  final top = math.max(a.top, b.top);
  final right = math.min(a.left + a.width, b.left + b.width);
  final bottom = math.min(a.top + a.height, b.top + b.height);
  if (right <= left || bottom <= top) return 0;

  var inter = 0;
  for (var y = top; y < bottom; y++) {
    final rowA = (y - a.top) * a.width - a.left;
    final rowB = (y - b.top) * b.width - b.left;
    for (var x = left; x < right; x++) {
      if (a.bytes[rowA + x] != 0 && b.bytes[rowB + x] != 0) inter++;
    }
  }
  if (inter == 0) return 0;
  return inter / math.max(1, math.min(a.pixelCount, b.pixelCount));
}

/// Merges per-tile detections into one mask per leaf.
///
/// Whole leaves go first, best score first; tile-cut pieces are only kept when
/// no whole leaf already covers them. Anything overlapping a kept mask by
/// [maxOverlap] or more is a duplicate from an overlapping tile.
List<LeafMask> mergeLeafDetections(
  List<LeafDetection> detections, {
  double maxOverlap = 0.5,
}) {
  final ordered = [...detections]..sort((a, b) {
    if (a.cutByTileEdge != b.cutByTileEdge) return a.cutByTileEdge ? 1 : -1;
    return b.score.compareTo(a.score);
  });
  final kept = <LeafMask>[];
  for (final d in ordered) {
    if (kept.every((k) => maskOverlapRatio(d.mask, k) < maxOverlap)) {
      kept.add(d.mask);
    }
  }
  return kept;
}
