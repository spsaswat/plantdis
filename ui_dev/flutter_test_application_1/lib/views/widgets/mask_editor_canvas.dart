import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_test_application_1/utils/mask_ops.dart';
import 'package:flutter_test_application_1/views/widgets/mask_editor_controller.dart';

/// Displays an image with its leaf masks overlaid and lets the user paint,
/// erase and select them.
///
/// Rendering is split so a drag stays cheap: the masks are composited into one
/// overlay image at working resolution and only rebuilt when a stroke *ends*,
/// while the in-progress stroke is drawn as a vector polyline on top.
class MaskEditorCanvas extends StatefulWidget {
  const MaskEditorCanvas({
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.controller,
    super.key,
  });

  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final MaskEditorController controller;

  @override
  State<MaskEditorCanvas> createState() => _MaskEditorCanvasState();
}

class _MaskEditorCanvasState extends State<MaskEditorCanvas> {
  /// Longest overlay edge in pixels. Enough for on-screen review without
  /// composing a full 20 MP RGBA buffer on every edit.
  static const int _maxOverlayEdge = 1500;

  ui.Image? _overlay;
  bool _regenerating = false;
  bool _regenerateQueued = false;

  List<Offset> _strokePoints = const [];
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _regenerateOverlay();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _overlay?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    _regenerateOverlay();
  }

  ({int width, int height}) get _overlaySize {
    final scale = math.min(
      1.0,
      _maxOverlayEdge / math.max(widget.imageWidth, widget.imageHeight),
    );
    return (
      width: math.max(1, (widget.imageWidth * scale).round()),
      height: math.max(1, (widget.imageHeight * scale).round()),
    );
  }

  Future<void> _regenerateOverlay() async {
    // Coalesce bursts: one regeneration in flight, at most one queued.
    if (_regenerating) {
      _regenerateQueued = true;
      return;
    }
    _regenerating = true;
    try {
      final controller = widget.controller;
      final masks = controller.masks;
      final size = _overlaySize;
      final selectedIndex = masks.indexWhere(
        (m) => m.id == controller.selectedId,
      );

      ui.Image? image;
      if (masks.isNotEmpty) {
        final rgba = composeOverlayRgba(
          masks: [for (final m in masks) m.mask],
          colors: [for (final m in masks) controller.colorOf(m)],
          selectedIndex: selectedIndex == -1 ? null : selectedIndex,
          imageWidth: widget.imageWidth,
          imageHeight: widget.imageHeight,
          overlayWidth: size.width,
          overlayHeight: size.height,
        );
        final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
        final descriptor = ui.ImageDescriptor.raw(
          buffer,
          width: size.width,
          height: size.height,
          pixelFormat: ui.PixelFormat.rgba8888,
        );
        final codec = await descriptor.instantiateCodec();
        image = (await codec.getNextFrame()).image;
        codec.dispose();
        descriptor.dispose();
        buffer.dispose();
      }

      if (!mounted) {
        image?.dispose();
        return;
      }
      setState(() {
        _overlay?.dispose();
        _overlay = image;
      });
    } finally {
      _regenerating = false;
      if (_regenerateQueued) {
        _regenerateQueued = false;
        unawaited(_regenerateOverlay());
      }
    }
  }

  Offset _toImageSpace(Offset local) {
    if (_canvasSize.width == 0 || _canvasSize.height == 0) return Offset.zero;
    return Offset(
      (local.dx / _canvasSize.width * widget.imageWidth).clamp(
        0.0,
        widget.imageWidth - 1,
      ),
      (local.dy / _canvasSize.height * widget.imageHeight).clamp(
        0.0,
        widget.imageHeight - 1,
      ),
    );
  }

  void _handleTap(Offset local) {
    final index = widget.controller.hitTest(_toImageSpace(local));
    widget.controller.select(
      index == null ? null : widget.controller.masks[index].id,
    );
  }

  void _endStroke() {
    if (_strokePoints.isNotEmpty) {
      widget.controller.applyStroke(_strokePoints);
    }
    setState(() => _strokePoints = const []);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final drawing = controller.tool != MaskTool.pan;
    final aspectRatio = widget.imageWidth / widget.imageHeight;
    final selected = controller.selected;

    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width / aspectRatio;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * aspectRatio;
        }
        _canvasSize = Size(width, height);
        final displayScale = width / widget.imageWidth;

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: InteractiveViewer(
              maxScale: 8,
              // Panning the view and painting into a mask are the same gesture,
              // so only one of them can be live at a time.
              panEnabled: !drawing,
              scaleEnabled: !drawing,
              child: GestureDetector(
                key: const Key('mask-editor-gesture-area'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _handleTap(details.localPosition),
                onPanStart:
                    drawing
                        ? (details) => setState(() {
                          _strokePoints = [
                            _toImageSpace(details.localPosition),
                          ];
                        })
                        : null,
                onPanUpdate:
                    drawing
                        ? (details) => setState(() {
                          _strokePoints = [
                            ..._strokePoints,
                            _toImageSpace(details.localPosition),
                          ];
                        })
                        : null,
                onPanEnd: drawing ? (_) => _endStroke() : null,
                onPanCancel:
                    drawing
                        ? () => setState(() => _strokePoints = const [])
                        : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      semanticLabel: 'Drone image with segmentation masks',
                    ),
                    if (_overlay case final overlay?)
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _MaskOverlayPainter(overlay: overlay),
                        ),
                      ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _StrokePainter(
                          points: _strokePoints,
                          displayScale: displayScale,
                          brushRadius: controller.brushRadiusImagePx,
                          erasing: controller.tool == MaskTool.erase,
                          color:
                              selected == null
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Color(
                                    0xFF000000 | controller.colorOf(selected),
                                  ),
                          selectedBounds:
                              selected == null || selected.mask.isEmpty
                                  ? null
                                  : Rect.fromLTWH(
                                    selected.mask.left * displayScale,
                                    selected.mask.top * displayScale,
                                    selected.mask.width * displayScale,
                                    selected.mask.height * displayScale,
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MaskOverlayPainter extends CustomPainter {
  const _MaskOverlayPainter({required this.overlay});

  final ui.Image overlay;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      overlay,
      Rect.fromLTWH(
        0,
        0,
        overlay.width.toDouble(),
        overlay.height.toDouble(),
      ),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _MaskOverlayPainter oldDelegate) =>
      oldDelegate.overlay != overlay;
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter({
    required this.points,
    required this.displayScale,
    required this.brushRadius,
    required this.erasing,
    required this.color,
    required this.selectedBounds,
  });

  final List<Offset> points;
  final double displayScale;
  final double brushRadius;
  final bool erasing;
  final Color color;
  final Rect? selectedBounds;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedBounds case final bounds?) {
      canvas.drawRect(
        bounds,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    if (points.isEmpty) return;

    final paint =
        Paint()
          ..color = erasing ? Colors.white.withValues(alpha: 0.8) : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = brushRadius * 2 * displayScale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(points.first.dx * displayScale, points.first.dy * displayScale);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx * displayScale, p.dy * displayScale);
    }
    if (points.length == 1) {
      canvas.drawCircle(
        Offset(
          points.first.dx * displayScale,
          points.first.dy * displayScale,
        ),
        brushRadius * displayScale,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedBounds != selectedBounds ||
        oldDelegate.brushRadius != brushRadius ||
        oldDelegate.erasing != erasing ||
        oldDelegate.color != color;
  }
}
