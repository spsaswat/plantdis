import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
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

  /// Owned rather than left to [InteractiveViewer] so the zoom level can be
  /// read back: the pen is sized in screen pixels, so it needs the scale.
  final TransformationController _viewTransform = TransformationController();

  /// Fingers currently down, and whether this gesture ever had two of them.
  ///
  /// The latch matters: lifting one finger of a pinch must not let the other
  /// carry on as a stroke, so it only clears once every finger is up.
  int _pointers = 0;
  bool _pinching = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _viewTransform.addListener(_onViewChanged);
    _regenerateOverlay();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _viewTransform.removeListener(_onViewChanged);
    _viewTransform.dispose();
    _overlay?.dispose();
    super.dispose();
  }

  /// Zooming changes how many image pixels the pen covers, so the controller
  /// is told the new scale straight away — a stroke started after this must
  /// use it.
  ///
  /// Repainting is another matter: the only thing on screen that reads the
  /// scale is the stroke preview, so a wheel notch or a pinch frame rebuilds
  /// nothing unless a stroke is actually in progress.
  void _onViewChanged() {
    if (!mounted) return;
    if (_canvasSize.width > 0) {
      widget.controller.setViewScale(
        _imagePxPerScreenPx(_canvasSize.width / widget.imageWidth),
      );
    }
    if (_strokePoints.isNotEmpty) setState(() {});
  }

  /// Image pixels spanned by one on-screen pixel at the current zoom.
  double _imagePxPerScreenPx(double displayScale) {
    final zoom = _viewTransform.value.getMaxScaleOnAxis();
    if (displayScale <= 0 || zoom <= 0) return 1;
    return 1 / (displayScale * zoom);
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
    // A tap on bare image is left alone: it encloses nothing, so there is no
    // lasso in it, and dropping the selection would leave the pen with nothing
    // to draw into. Tapping the selected mask again is how it is let go.
    if (index == null) return;
    final id = widget.controller.masks[index].id;
    widget.controller.select(id == widget.controller.selectedId ? null : id);
  }

  void _releasePointer() {
    _pointers = math.max(0, _pointers - 1);
    if (_pointers == 0) _pinching = false;
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
        // Silent by contract, so this layout pass does not trigger a rebuild.
        controller.setViewScale(_imagePxPerScreenPx(displayScale));

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: InteractiveViewer(
              transformationController: _viewTransform,
              maxScale: 8,
              // Left drags are strokes and never reach here: a drag
              // recognizer only accepts the primary button, so the right
              // button is what moves the view. The wheel zooms it. A stroke
              // claims one pointer only, so a second finger reaches this and
              // drags the view instead. Neither can be confused with drawing,
              // so there is no mode to switch to.
              child: Listener(
                behavior: HitTestBehavior.deferToChild,
                onPointerDown: (_) {
                  _pointers++;
                  // A second finger means a pinch. Drop whatever the first one
                  // had started so the zoom does not leave a stroke behind.
                  if (_pointers > 1) {
                    _pinching = true;
                    if (_strokePoints.isNotEmpty) {
                      setState(() => _strokePoints = const []);
                    }
                  }
                },
                onPointerUp: (_) => _releasePointer(),
                onPointerCancel: (_) => _releasePointer(),
                child: RawGestureDetector(
                  key: const Key('mask-editor-gesture-area'),
                  behavior: HitTestBehavior.opaque,
                  gestures: <Type, GestureRecognizerFactory>{
                    TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                      TapGestureRecognizer
                    >(TapGestureRecognizer.new, (recognizer) {
                      recognizer.onTapUp =
                          (details) => _handleTap(details.localPosition);
                    }),
                    _StrokeRecognizer: GestureRecognizerFactoryWithHandlers<
                      _StrokeRecognizer
                    >(_StrokeRecognizer.new, (recognizer) {
                      recognizer
                        ..onStart = (details) {
                          if (_pinching) return;
                          setState(() {
                            _strokePoints = [
                              _toImageSpace(details.localPosition),
                            ];
                          });
                        }
                        ..onUpdate = (details) {
                          if (_pinching) return;
                          setState(() {
                            _strokePoints = [
                              ..._strokePoints,
                              _toImageSpace(details.localPosition),
                            ];
                          });
                        }
                        ..onEnd = ((_) => _endStroke())
                        ..onCancel =
                            (() => setState(() => _strokePoints = const []));
                    }),
                  },
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
                            penRadius: controller.penRadiusImagePx,
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
      Rect.fromLTWH(0, 0, overlay.width.toDouble(), overlay.height.toDouble()),
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
    required this.penRadius,
    required this.erasing,
    required this.color,
    required this.selectedBounds,
  });

  final List<Offset> points;
  final double displayScale;
  final double penRadius;
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
          // 2r+1 image pixels wide, and never thinner than a hairline, so a
          // one-pixel nib still previews where the line will land.
          ..strokeWidth = math.max(1.0, (penRadius * 2 + 1) * displayScale)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path =
        Path()..moveTo(
          points.first.dx * displayScale,
          points.first.dy * displayScale,
        );
    for (final p in points.skip(1)) {
      path.lineTo(p.dx * displayScale, p.dy * displayScale);
    }
    if (points.length == 1) {
      canvas.drawCircle(
        Offset(points.first.dx * displayScale, points.first.dy * displayScale),
        math.max(0.5, (penRadius + 0.5) * displayScale),
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    canvas.drawPath(path, paint);

    // The stroke is closed for the user on release, and where that join lands
    // decides what ends up enclosed. Dashed, so it reads as the part they have
    // not drawn.
    if (points.length > 2) {
      _dash(
        canvas,
        Offset(points.last.dx * displayScale, points.last.dy * displayScale),
        Offset(points.first.dx * displayScale, points.first.dy * displayScale),
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, paint.strokeWidth / 2),
      );
    }
  }

  /// A dashed line from [from] to [to], 6 on 6 off.
  void _dash(Canvas canvas, Offset from, Offset to, Paint paint) {
    final span = to - from;
    final length = span.distance;
    if (length == 0) return;
    final step = span / length;
    for (var at = 0.0; at < length; at += 12) {
      canvas.drawLine(
        from + step * at,
        from + step * math.min(at + 6, length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedBounds != selectedBounds ||
        oldDelegate.penRadius != penRadius ||
        oldDelegate.erasing != erasing ||
        oldDelegate.color != color;
  }
}

/// A drag recognizer for one stroke, which claims a single pointer.
///
/// [PanGestureRecognizer] would win the arena for every pointer on the canvas,
/// including the second finger of a pinch, leaving [InteractiveViewer] nothing
/// to work with. Refusing the extra pointer lets the viewer have it, so two
/// fingers move the image on a touch screen the way the right button does with
/// a mouse.
class _StrokeRecognizer extends PanGestureRecognizer {
  int? _claimed;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      _claimed == null && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _claimed = event.pointer;
    super.addAllowedPointer(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _claimed = null;
    super.didStopTrackingLastPointer(pointer);
  }
}
