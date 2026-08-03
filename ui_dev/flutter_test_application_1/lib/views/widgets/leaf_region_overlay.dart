import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test_application_1/models/drone_batch_model.dart';
import 'package:flutter_test_application_1/utils/local_path_utils.dart';

/// Resolves the app's polymorphic image sources — `file://` URIs, bare Windows
/// paths and `https://` download URLs — into an [ImageProvider].
///
/// [bytes] wins when present, which lets the drone pages render instantly from
/// the bytes carried in the batch request.
ImageProvider? plantImageProvider(String? source, {Uint8List? bytes}) {
  if (bytes != null && bytes.isNotEmpty) return MemoryImage(bytes);
  final src = source?.trim();
  if (src == null || src.isEmpty) return null;
  if (isLocalFilesystemPath(src)) return FileImage(File(toLocalFilePath(src)));
  return NetworkImage(src);
}

/// Colour used for a leaf's box and status chip.
Color leafStatusColor(BatchLeafEntry entry, ColorScheme scheme) {
  switch (entry.status) {
    case LeafStatus.completed:
      return entry.isHealthy ? Colors.green : Colors.orange;
    case LeafStatus.error:
      return scheme.error;
    case LeafStatus.processing:
      return scheme.primary;
    default:
      return Colors.grey;
  }
}

/// Default cap on how tall a framed drone image may get.
const double kLeafRegionFrameMaxHeight = 300;

/// A [LeafRegionOverlay] sized to the image's own aspect ratio.
///
/// Prefer this over placing the overlay in a fixed-height box: a fixed-height
/// box is as wide as its parent, so a landscape drone image letterboxes inside
/// it and leaves wide empty bars either side on a desktop window. Driving the
/// frame from the aspect ratio means the container is exactly the size of the
/// image, with no leftover background at all.
class LeafRegionFrame extends StatelessWidget {
  const LeafRegionFrame({
    required this.image,
    required this.imageAspectRatio,
    required this.entries,
    this.maxHeight = kLeafRegionFrameMaxHeight,
    this.activeIndex,
    this.onLeafTap,
    super.key,
  });

  final ImageProvider? image;
  final double imageAspectRatio;
  final List<BatchLeafEntry> entries;
  final double maxHeight;
  final int? activeIndex;
  final ValueChanged<BatchLeafEntry>? onLeafTap;

  @override
  Widget build(BuildContext context) {
    final aspectRatio =
        imageAspectRatio.isFinite && imageAspectRatio > 0
            ? imageAspectRatio
            : 4 / 3;
    final provider = image;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                provider == null
                    ? const ColoredBox(
                      color: Colors.black26,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    )
                    : LeafRegionOverlay(
                      image: provider,
                      imageAspectRatio: aspectRatio,
                      entries: entries,
                      activeIndex: activeIndex,
                      onLeafTap: onLeafTap,
                    ),
          ),
        ),
      ),
    );
  }
}

/// The drone image with one numbered box per labelled leaf.
///
/// Uses the same letterbox math as `RectangleLabelCanvas` so the boxes land
/// exactly where the user drew them.
class LeafRegionOverlay extends StatelessWidget {
  const LeafRegionOverlay({
    required this.image,
    required this.imageAspectRatio,
    required this.entries,
    this.activeIndex,
    this.onLeafTap,
    super.key,
  });

  final ImageProvider image;
  final double imageAspectRatio;
  final List<BatchLeafEntry> entries;

  /// Leaf currently being processed, drawn with a heavier outline.
  final int? activeIndex;
  final ValueChanged<BatchLeafEntry>? onLeafTap;

  BatchLeafEntry? _hitTest(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return null;
    final nx = local.dx / size.width;
    final ny = local.dy / size.height;
    // Reverse order so the box drawn last (on top) wins an overlap.
    for (final entry in entries.reversed) {
      final r = entry.region;
      if (nx >= r.x &&
          nx <= r.x + r.width &&
          ny >= r.y &&
          ny <= r.y + r.height) {
        return entry;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final safeAspectRatio =
        imageAspectRatio.isFinite && imageAspectRatio > 0
            ? imageAspectRatio
            : 4 / 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        var width = availableWidth;
        var height = width / safeAspectRatio;
        if (height.isFinite &&
            availableHeight.isFinite &&
            height > availableHeight) {
          height = availableHeight;
          width = height * safeAspectRatio;
        }
        final canvasSize = Size(width, height);

        return Center(
          child: SizedBox.fromSize(
            size: canvasSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp:
                  onLeafTap == null
                      ? null
                      : (details) {
                        final hit = _hitTest(details.localPosition, canvasSize);
                        if (hit != null) onLeafTap!(hit);
                      },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: image,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    semanticLabel: 'Drone image with labelled leaf regions',
                    errorBuilder:
                        (context, error, stackTrace) => const ColoredBox(
                          color: Colors.black26,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _LeafRegionPainter(
                        entries: entries,
                        activeIndex: activeIndex,
                        scheme: Theme.of(context).colorScheme,
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

class _LeafRegionPainter extends CustomPainter {
  const _LeafRegionPainter({
    required this.entries,
    required this.activeIndex,
    required this.scheme,
  });

  final List<BatchLeafEntry> entries;
  final int? activeIndex;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in entries) {
      final r = entry.region;
      final rect = Rect.fromLTWH(
        r.x * size.width,
        r.y * size.height,
        r.width * size.width,
        r.height * size.height,
      );
      final color = leafStatusColor(entry, scheme);
      final isActive = activeIndex == entry.index;

      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: isActive ? 0.28 : 0.14),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 3.5 : 2,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${entry.index + 1}',
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
  }

  @override
  bool shouldRepaint(covariant _LeafRegionPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex ||
        !listEquals(oldDelegate.entries, entries);
  }
}
