import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';

class RectangleLabelCanvas extends StatefulWidget {
  const RectangleLabelCanvas({
    required this.imageBytes,
    required this.imageAspectRatio,
    required this.labels,
    required this.onLabelCreated,
    this.enabled = true,
    super.key,
  });

  final Uint8List imageBytes;
  final double imageAspectRatio;
  final List<NormalizedLabelRect> labels;
  final ValueChanged<NormalizedLabelRect> onLabelCreated;
  final bool enabled;

  @override
  State<RectangleLabelCanvas> createState() => _RectangleLabelCanvasState();
}

class _RectangleLabelCanvasState extends State<RectangleLabelCanvas> {
  static const double _minimumLabelSize = 0.01;

  Offset? _start;
  Offset? _current;

  Offset _normalized(Offset localPosition, Size size) {
    return Offset(
      (localPosition.dx / size.width).clamp(0.0, 1.0),
      (localPosition.dy / size.height).clamp(0.0, 1.0),
    );
  }

  NormalizedLabelRect? get _draft {
    final start = _start;
    final current = _current;
    if (start == null || current == null) return null;
    return NormalizedLabelRect.fromCorners(
      startX: start.dx,
      startY: start.dy,
      endX: current.dx,
      endY: current.dy,
    );
  }

  void _finishLabel() {
    final draft = _draft;
    if (draft != null &&
        draft.width >= _minimumLabelSize &&
        draft.height >= _minimumLabelSize) {
      widget.onLabelCreated(draft);
    }
    setState(() {
      _start = null;
      _current = null;
    });
  }

  void _cancelLabel() {
    setState(() {
      _start = null;
      _current = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        var width = availableWidth;
        var height = width / widget.imageAspectRatio;
        if (height > availableHeight) {
          height = availableHeight;
          width = height * widget.imageAspectRatio;
        }
        final canvasSize = Size(width, height);

        return Center(
          child: SizedBox.fromSize(
            size: canvasSize,
            child: GestureDetector(
              key: const Key('rectangle-label-gesture-area'),
              behavior: HitTestBehavior.opaque,
              onPanStart:
                  widget.enabled
                      ? (details) {
                        setState(() {
                          _start = _normalized(
                            details.localPosition,
                            canvasSize,
                          );
                          _current = _start;
                        });
                      }
                      : null,
              onPanUpdate:
                  widget.enabled
                      ? (details) {
                        setState(() {
                          _current = _normalized(
                            details.localPosition,
                            canvasSize,
                          );
                        });
                      }
                      : null,
              onPanEnd: widget.enabled ? (_) => _finishLabel() : null,
              onPanCancel: widget.enabled ? _cancelLabel : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    semanticLabel: 'Drone image to label',
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _RectangleLabelPainter(
                        labels: widget.labels,
                        draft: _draft,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RectangleLabelPainter extends CustomPainter {
  const _RectangleLabelPainter({
    required this.labels,
    required this.draft,
    required this.color,
  });

  final List<NormalizedLabelRect> labels;
  final NormalizedLabelRect? draft;
  final Color color;

  Rect _toRect(NormalizedLabelRect label, Size size) {
    return Rect.fromLTWH(
      label.x * size.width,
      label.y * size.height,
      label.width * size.width,
      label.height * size.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = color.withValues(alpha: 0.16);
    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    for (var index = 0; index < labels.length; index++) {
      final rect = _toRect(labels[index], size);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, strokePaint);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: TextStyle(
            color: color,
            backgroundColor: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, rect.topLeft + const Offset(3, 3));
    }

    if (draft case final draft?) {
      final draftPaint =
          Paint()
            ..color = color.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
      canvas.drawRect(_toRect(draft, size), draftPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RectangleLabelPainter oldDelegate) {
    return oldDelegate.labels != labels || oldDelegate.draft != draft;
  }
}
