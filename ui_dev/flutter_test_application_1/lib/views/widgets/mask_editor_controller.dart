import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/utils/mask_ops.dart';

/// What a drag on the mask canvas does.
enum MaskTool {
  /// Pan and zoom the image.
  pan,

  /// Add pixels to the selected mask.
  paint,

  /// Remove pixels from the selected mask.
  erase,
}

/// A mask in the editor, with a stable identity so selection survives edits.
class EditableMask {
  EditableMask({required this.id, required this.mask, required this.colorIndex});

  final int id;
  LeafMask mask;
  final int colorIndex;
}

/// Editing state for a set of leaf masks over one image.
///
/// Deliberately free of any file-format or drone-flow specifics: constructing
/// it with `initialMasks: []` gives a from-scratch mask labelling session, which
/// is how the manual flow can move off rectangles later.
class MaskEditorController extends ChangeNotifier {
  MaskEditorController({
    required this.imageWidth,
    required this.imageHeight,
    List<LeafMask> initialMasks = const [],
  }) {
    for (final mask in initialMasks) {
      // Normalize up front, so masks are one solid piece however they were
      // sourced.
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
    0xE53935, 0x43A047, 0x1E88E5, 0xFDD835, 0x8E24AA,
    0x00ACC1, 0xFB8C00, 0x3949AB, 0x00897B, 0xD81B60,
  ];

  static const int _maxUndoDepth = 10;

  final int imageWidth;
  final int imageHeight;

  final List<EditableMask> _masks = [];
  final List<_UndoStep> _undoStack = [];

  int _nextId = 1;
  int _nextColorIndex = 0;

  int? _selectedId;
  MaskTool _tool = MaskTool.pan;
  double _brushRadiusImagePx = 24;

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
  double get brushRadiusImagePx => _brushRadiusImagePx;
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
    // Painting needs a target; fall back to the first mask.
    if (tool != MaskTool.pan && selected == null && _masks.isNotEmpty) {
      _selectedId = _masks.first.id;
    }
    _tool = tool;
    notifyListeners();
  }

  void setBrushRadius(double radius) {
    final clamped = radius.clamp(1.0, 400.0);
    if (_brushRadiusImagePx == clamped) return;
    _brushRadiusImagePx = clamped;
    notifyListeners();
  }

  /// Adds an empty mask, selects it, and switches to the paint tool so the next
  /// drag draws into it.
  int addEmptyMask() {
    final mask = EditableMask(
      id: _nextId++,
      mask: LeafMask.emptyAt(imageWidth: imageWidth, imageHeight: imageHeight),
      colorIndex: _nextColorIndex++,
    );
    _masks.add(mask);
    _selectedId = mask.id;
    _tool = MaskTool.paint;
    _pushUndo(_UndoStep.added(mask.id));
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

  /// Rasterizes a stroke through [imagePoints] (full-image pixel coordinates)
  /// into the selected mask.
  ///
  /// The mask is normalized back to a single solid region afterwards, which has
  /// two consequences worth knowing: erasing into the middle does not punch a
  /// hole through the leaf (erase trims the outline), and an edit that would
  /// leave two separate pieces keeps only the larger one. [undo] steps back
  /// over the whole stroke, normalization included.
  void applyStroke(List<Offset> imagePoints) {
    final target = selected;
    if (target == null || imagePoints.isEmpty || _tool == MaskTool.pan) return;

    _pushUndo(_UndoStep.edited(target.id, target.mask.deepCopy()));
    target.mask = solidifyMask(
      applyStrokeToMask(
        target.mask,
        [for (final p in imagePoints) math.Point<double>(p.dx, p.dy)],
        radius: _brushRadiusImagePx.round(),
        erase: _tool == MaskTool.erase,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      ),
    );
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
