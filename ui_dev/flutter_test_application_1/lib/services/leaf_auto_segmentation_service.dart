import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/utils/analysis_utils.dart';
import 'package:flutter_test_application_1/utils/maskrcnn_postprocess.dart';

/// Thrown when automatic segmentation cannot produce masks.
class AutoSegmentationException implements Exception {
  const AutoSegmentationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the caller cancels a run.
class AutoSegmentationCancelled implements Exception {
  const AutoSegmentationCancelled();
}

/// Finds every leaf in a drone frame with the client's Mask R-CNN
/// (`maskrcnn_resnet50_fpn_v2`, one "leaf" class).
///
/// The model was trained on 1024 px tiles with 35% overlap, so the frame is
/// processed the same way and per-tile results are merged. The ONNX graph
/// returns boxes, scores and unpasted 28×28 mask probabilities; pasting happens
/// here, which keeps a tile's output small.
class LeafAutoSegmentationService {
  LeafAutoSegmentationService._();

  static const String modelAssetPath = 'assets/models/leaf_mask_rcnn_v3.onnx';

  /// Training-time tiling; changing these degrades results.
  static const int tileSize = 1024;
  static const double tileOverlap = 0.35;

  static const double _overlapSpan = tileSize * tileOverlap;

  /// The exported graph already drops detections below 0.3.
  static const double scoreThreshold = 0.5;

  /// Returns one tight [LeafMask] per leaf, in the pixel space of the
  /// EXIF-oriented image ([imageWidth]×[imageHeight], as the mask editor
  /// measures it).
  ///
  /// Runs in a background isolate. [onProgress] gets (tiles done, tiles
  /// total). Completing [cancel] stops the run and throws
  /// [AutoSegmentationCancelled].
  static Future<List<LeafMask>> segment(
    Uint8List imageBytes, {
    required int imageWidth,
    required int imageHeight,
    void Function(int done, int total)? onProgress,
    Future<void>? cancel,
  }) async {
    final Uint8List model;
    try {
      final data = await rootBundle.load(modelAssetPath);
      model = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      throw const AutoSegmentationException(
        'The leaf segmentation model is missing ($modelAssetPath).',
      );
    }

    final port = ReceivePort();
    final result = Completer<List<LeafMask>>();
    Isolate? isolate;

    port.listen((message) {
      if (result.isCompleted) return;
      switch (message) {
        case (int done, int total):
          onProgress?.call(done, total);
        case List<LeafMask> masks:
          result.complete(masks);
        case [final Object? error, final Object? _]:
          // Uncaught worker error, delivered by Isolate.spawn's onError.
          result.completeError(
            error is String && error.startsWith('AutoSegmentationException: ')
                ? AutoSegmentationException(
                  error.substring('AutoSegmentationException: '.length),
                )
                : AutoSegmentationException(
                  'Automatic segmentation failed: $error',
                ),
          );
        case null:
          result.completeError(
            const AutoSegmentationException(
              'Automatic segmentation stopped unexpectedly.',
            ),
          );
      }
    });
    cancel?.then((_) {
      if (result.isCompleted) return;
      isolate?.kill(priority: Isolate.immediate);
      result.completeError(const AutoSegmentationCancelled());
    });

    try {
      isolate = await Isolate.spawn(
        _run,
        _Job(port.sendPort, imageBytes, model, imageWidth, imageHeight),
        onError: port.sendPort,
        onExit: port.sendPort,
        debugName: 'LeafAutoSegmentation',
      );
      return await result.future;
    } finally {
      port.close();
    }
  }

  static void _run(_Job job) {
    try {
      job.port.send(_segmentSync(job));
    } on AutoSegmentationException catch (e) {
      // Only the message survives the isolate boundary via onError.
      throw 'AutoSegmentationException: ${e.message}';
    }
  }

  static List<LeafMask> _segmentSync(_Job job) {
    final oriented = decodeOriented(job.imageBytes).image;
    if (oriented.width != job.imageWidth ||
        oriented.height != job.imageHeight) {
      throw AutoSegmentationException(
        'The decoded image is ${oriented.width} x ${oriented.height} but '
        'expected ${job.imageWidth} x ${job.imageHeight}.',
      );
    }
    final width = oriented.width;
    final height = oriented.height;
    final rgb = oriented
        .convert(format: img.Format.uint8, numChannels: 3)
        .getBytes(order: img.ChannelOrder.rgb);

    final stride = (tileSize * (1 - tileOverlap)).floor();
    final ys = tileStarts(height, tileSize, stride);
    final xs = tileStarts(width, tileSize, stride);
    final total = ys.length * xs.length;
    job.port.send((0, total));

    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    final runOptions = OrtRunOptions();
    final session = OrtSession.fromBuffer(job.model, sessionOptions);
    final detections = <LeafDetection>[];
    try {
      var done = 0;
      for (final top in ys) {
        for (final left in xs) {
          final th = (height - top).clamp(0, tileSize);
          final tw = (width - left).clamp(0, tileSize);
          _runTile(
            session,
            runOptions,
            rgb,
            imageWidth: width,
            imageHeight: height,
            left: left,
            top: top,
            tileWidth: tw,
            tileHeight: th,
            into: detections,
          );
          job.port.send((++done, total));
        }
      }
    } finally {
      session.release();
      runOptions.release();
      sessionOptions.release();
      OrtEnv.instance.release();
    }
    return mergeLeafDetections(detections);
  }

  static void _runTile(
    OrtSession session,
    OrtRunOptions runOptions,
    Uint8List rgb, {
    required int imageWidth,
    required int imageHeight,
    required int left,
    required int top,
    required int tileWidth,
    required int tileHeight,
    required List<LeafDetection> into,
  }) {
    // CHW float input in 0..1; normalisation is inside the graph.
    final plane = tileWidth * tileHeight;
    final input = Float32List(plane * 3);
    for (var y = 0; y < tileHeight; y++) {
      var src = ((top + y) * imageWidth + left) * 3;
      var dst = y * tileWidth;
      for (var x = 0; x < tileWidth; x++, src += 3, dst++) {
        input[dst] = rgb[src] / 255.0;
        input[plane + dst] = rgb[src + 1] / 255.0;
        input[2 * plane + dst] = rgb[src + 2] / 255.0;
      }
    }

    final tensor = OrtValueTensor.createTensorWithDataList(input, [
      1,
      3,
      tileHeight,
      tileWidth,
    ]);
    final outputs = session.run(runOptions, {'input': tensor});
    tensor.release();
    try {
      final scores = outputs[1]!.value as List;
      if (scores.isEmpty) return;
      final boxes = outputs[0]!.value as List;
      final masks = outputs[2]!.value as List;
      for (var i = 0; i < scores.length; i++) {
        final score = (scores[i] as num).toDouble();
        if (score < scoreThreshold) continue;
        final box = (boxes[i] as List).cast<double>();

        final cut = touchesInnerTileEdge(
          x0: box[0],
          y0: box[1],
          x1: box[2],
          y1: box[3],
          tileLeft: left,
          tileTop: top,
          tileWidth: tileWidth,
          tileHeight: tileHeight,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );
        // A leaf smaller than the overlap band fits whole in a neighbouring
        // tile, so its cut-off piece here is only a sliver. Bigger leaves may
        // be cut in every tile; keep those pieces as a fallback.
        if (cut &&
            box[2] - box[0] < _overlapSpan &&
            box[3] - box[1] < _overlapSpan) {
          continue;
        }

        final rows = (masks[i] as List)[0] as List;
        final size = rows.length;
        final probs = Float32List(size * size);
        for (var r = 0; r < size; r++) {
          probs.setRange(
            r * size,
            (r + 1) * size,
            (rows[r] as List).cast<double>(),
          );
        }

        final mask = pasteMaskRcnnMask(
          probs: probs,
          maskSize: size,
          x0: box[0],
          y0: box[1],
          x1: box[2],
          y1: box[3],
          tileWidth: tileWidth,
          tileHeight: tileHeight,
          offsetX: left,
          offsetY: top,
        );
        if (mask == null) continue;
        into.add(LeafDetection(mask: mask, score: score, cutByTileEdge: cut));
      }
    } finally {
      for (final o in outputs) {
        o?.release();
      }
    }
  }
}

class _Job {
  const _Job(
    this.port,
    this.imageBytes,
    this.model,
    this.imageWidth,
    this.imageHeight,
  );

  final SendPort port;
  final Uint8List imageBytes;
  final Uint8List model;
  final int imageWidth;
  final int imageHeight;
}
