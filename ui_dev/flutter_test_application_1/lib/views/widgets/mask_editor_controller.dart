import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/utils/mask_ops.dart';

/// What a left drag on the mask canvas does.
///
/// Both are lassos, never brushes: the line drawn is a boundary with no width
/// of its own, and what it encloses is the region added or taken away. There
/// is no tool for moving the view — the right button drags it and the wheel
/// zooms it, whichever of these is selected.
enum MaskTool {
  /// Add what the line encloses to the selected mask.
  paint,

  /// Take what the line encloses out of the selected mask.
  erase,
}

/// A mask in the editor, with a stable identity so selection survives edits.
class EditableMask {
  EditableMask({
    required this.id,
    required this.mask,
    required this.colorIndex,
  });

  final int id;

  /// The leaf: one solid region, whatever the lassos that built it enclosed.
  LeafMask mask;

  final int colorIndex;
}

/// Editing state for a set of leaf masks over one image.
///
/// Deliberately free of any file-format or drone-flow specifics: constructing
/// it with `initialMasks: []` gives a from-scratch mask labelling session, which
/// is what the manual drone flow does.
class MaskEditorController extends ChangeNotifier {
  MaskEditorController({
    required this.imageWidth,
    required this.imageHeight,
    List<LeafMask> initialMasks = const [],
  }) {
    for (final mask in initialMasks) {
      // Normalize up front, so masks are one solid piece however they were
      // sourced. A supplied region doubles as its own edge.
      _masks.add(
        EditableMask(
          id: _nextId++,
          mask: solidifyMask(mask),
          colorIndex: _nextColorIndex++,
        ),
      );
    }
  }

  /// Distinct hues so neighbouring leaves stay tellable apart. 0xRRGGBB.
  static const List<int> maskColors = [
    0xE53935,
    0x43A047,
    0x1E88E5,
    0xFDD835,
    0x8E24AA,
    0x00ACC1,
    0xFB8C00,
    0x3949AB,
    0x00897B,
    0xD81B60,
  ];

  static const int _maxUndoDepth = 10;

  final int imageWidth;
  final int imageHeight;

  final List<EditableMask> _masks = [];
  final List<_UndoStep> _undoStack = [];

  int _nextId = 1;
  int _nextColorIndex = 0;

  int? _selectedId;
  MaskTool _tool = MaskTool.paint;

  /// Fixed boundary width in on-screen logical pixels, so the trace remains
  /// visible but never asks the user to tune a value that does not change the
  /// final lasso region.
  ///
  /// A pen, not a blob: the job is tracing the edge of a leaf, and
  /// [fillMaskHoles] floods the outline afterwards, so width buys nothing and
  /// costs precision.
  static const double _traceWidthScreenPx = 2;

  /// Image pixels covered by one on-screen pixel, pushed in by the canvas as
  /// the layout and zoom change. 1.0 until a canvas reports otherwise, which
  /// makes the two radii the same thing in tests.
  double _imagePxPerScreenPx = 1;

  List<EditableMask> get masks => List.unmodifiable(_masks);
  int get maskCount => _masks.length;

  int? get selectedId => _selectedId;
  EditableMask? get selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final m in _masks) {
      if (m.id == id) return m;
    }
    return null;
  }

  MaskTool get tool => _tool;

  /// The disc radius that draws the fixed-width boundary at the current zoom.
  ///
  /// A stamped disc of radius r is 2r+1 pixels across, so the requested width
  /// converts as (w-1)/2 — halving it instead would draw a line nearly twice
  /// as thick as the requested width. Zero is the useful floor: it is a
  /// one-pixel trace, which is what outlining an edge zoomed in needs.
  double get penRadiusImagePx {
    final widthImagePx = _traceWidthScreenPx * _imagePxPerScreenPx;
    return math.max(0.0, (widthImagePx - 1) / 2);
  }

  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there is anything worth processing — the Process button's gate.
  bool get hasUsableMasks => _masks.any((m) => !m.mask.isEmpty);

  int colorOf(EditableMask mask) =>
      maskColors[mask.colorIndex % maskColors.length];

  void select(int? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void setTool(MaskTool tool) {
    if (_tool == tool) return;
    // Drawing needs a target; fall back to the first mask.
    if (selected == null && _masks.isNotEmpty) {
      _selectedId = _masks.first.id;
    }
    _tool = tool;
    notifyListeners();
  }

  /// Reports how many image pixels one on-screen pixel now covers.
  ///
  /// Deliberately silent: the canvas calls this from its layout pass, and
  /// notifying there would rebuild mid-build. The canvas repaints itself when
  /// the view transform changes.
  void setViewScale(double imagePxPerScreenPx) {
    if (imagePxPerScreenPx <= 0 || !imagePxPerScreenPx.isFinite) return;
    _imagePxPerScreenPx = imagePxPerScreenPx;
  }

  /// Adds an empty mask, selects it, and switches to the paint tool so the next
  /// drag draws into it.
  ///
  /// [recordUndo] is false for the blank mask a from-scratch session opens
  /// with: there is nothing before it to step back to.
  int addEmptyMask({bool recordUndo = true}) {
    final mask = EditableMask(
      id: _nextId++,
      mask: LeafMask.emptyAt(imageWidth: imageWidth, imageHeight: imageHeight),
      colorIndex: _nextColorIndex++,
    );
    _masks.add(mask);
    _selectedId = mask.id;
    _tool = MaskTool.paint;
    if (recordUndo) _pushUndo(_UndoStep.added(mask.id));
    notifyListeners();
    return mask.id;
  }

  void removeMask(int id) {
    final at = _masks.indexWhere((m) => m.id == id);
    if (at == -1) return;
    final removed = _masks.removeAt(at);
    if (_selectedId == id) _selectedId = null;
    _pushUndo(_UndoStep.removed(at, removed));
    notifyListeners();
  }

  /// Applies a lasso stroke through [imagePoints] (full-image pixel
  /// coordinates) to the selected mask.
  ///
  /// The line is a boundary, not paint: what it encloses is added to the mask,
  /// or taken out of it when erasing. Its ends are joined if it does not close
  /// on its own, so a loop drawn by hand around a leaf works, and a stroke
  /// that encloses nothing even then — a dot, or a straight line — does
  /// nothing at all rather than leaving a smear behind.
  ///
  /// Adding: a region that touches the mask extends it; one drawn clear of it
  /// *replaces* it, because the loop just drawn is the leaf the user means.
  /// Taking away: the mask is left one solid piece, so an erase inside a leaf
  /// changes nothing (the hole seals) and one that severs it keeps the larger
  /// part. [undo] steps back over the whole stroke.
  void applyStroke(List<Offset> imagePoints) {
    final target = selected;
    if (target == null || imagePoints.isEmpty) return;

    final points = [
      for (final p in imagePoints) math.Point<double>(p.dx, p.dy),
    ];
    final region = lassoRegion(
      points,
      radius: penRadiusImagePx.round(),
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
    if (region.isEmpty) return;

    _pushUndo(_UndoStep.edited(target.id, target.mask.deepCopy()));
    if (_tool == MaskTool.erase) {
      target.mask = solidifyMask(subtractMask(target.mask, region));
    } else {
      // Anchored on the new region rather than the path that drew it, so the
      // piece kept is always the one just added. The region is not empty, so
      // it always has a pixel to anchor on.
      final anchor = anyPixelIn(region)!;
      target.mask = solidifyMaskAt(unionMask(target.mask, region), [anchor]);
    }
    notifyListeners();
  }

  /// Index of the mask under a full-image pixel coordinate, or null.
  int? hitTest(Offset imagePoint) {
    return hitTestMasks(
      [for (final m in _masks) m.mask],
      imagePoint.dx.floor(),
      imagePoint.dy.floor(),
    );
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final step = _undoStack.removeLast();
    switch (step.kind) {
      case _UndoKind.edited:
        final at = _masks.indexWhere((m) => m.id == step.id);
        if (at != -1) _masks[at].mask = step.mask!;
      case _UndoKind.added:
        _masks.removeWhere((m) => m.id == step.id);
        if (_selectedId == step.id) _selectedId = null;
      case _UndoKind.removed:
        _masks.insert(math.min(step.index!, _masks.length), step.entry!);
    }
    notifyListeners();
  }

  /// The masks to hand to the batch pipeline: one solid region each, empties
  /// dropped, and deep-copied so later edits cannot mutate an in-flight
  /// request.
  List<LeafMask> buildFinalMasks() {
    final result = <LeafMask>[];
    for (final m in _masks) {
      // Every edit already leaves the mask solid; this makes it a guarantee of
      // the hand-off rather than of the edit history.
      final solid = solidifyMask(m.mask);
      if (solid.isEmpty) continue;
      result.add(solid.deepCopy());
    }
    return result;
  }

  void _pushUndo(_UndoStep step) {
    _undoStack.add(step);
    if (_undoStack.length > _maxUndoDepth) _undoStack.removeAt(0);
  }
}

enum _UndoKind { edited, added, removed }

class _UndoStep {
  _UndoStep.edited(this.id, this.mask)
    : kind = _UndoKind.edited,
      index = null,
      entry = null;

  _UndoStep.added(this.id)
    : kind = _UndoKind.added,
      mask = null,
      index = null,
      entry = null;

  _UndoStep.removed(this.index, this.entry)
    : kind = _UndoKind.removed,
      id = entry!.id,
      mask = null;

  final _UndoKind kind;
  late final int id;
  final LeafMask? mask;
  final int? index;
  final EditableMask? entry;
}
