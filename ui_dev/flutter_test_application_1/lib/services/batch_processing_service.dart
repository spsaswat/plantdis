import 'dart:async';
import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

import 'package:flutter_test_application_1/data/disease_labels.dart';
import 'package:flutter_test_application_1/data/disease_suggestion_fallbacks.dart';
import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/drone_batch_model.dart';
import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/services/drone_batch_service.dart';
import 'package:flutter_test_application_1/services/leaf_analysis_pipeline.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/utils/analysis_utils.dart';
import 'package:flutter_test_application_1/utils/local_path_utils.dart';
import 'package:flutter_test_application_1/utils/logger.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';
import 'package:flutter_test_application_1/views/services/gemini_service.dart';

/// Snapshot of a running batch, emitted after every leaf.
class BatchProgress {
  const BatchProgress({
    required this.batchId,
    required this.total,
    required this.completed,
    required this.failed,
    this.currentIndex,
    this.stageMessage,
    this.done = false,
    this.cancelled = false,
    this.batch,
    this.error,
  });

  final String batchId;
  final int total;
  final int completed;
  final int failed;

  /// 0-based index of the leaf being worked on, or null when idle/finished.
  final int? currentIndex;
  final String? stageMessage;
  final bool done;
  final bool cancelled;

  /// Latest batch snapshot, so the UI can render per-leaf state without a
  /// second stream.
  final DroneBatchModel? batch;
  final Object? error;

  int get finished => completed + failed;
  double get fraction => total == 0 ? 0 : finished / total;
}

/// Crops each labelled region out of a drone image and runs the leaf pipeline
/// over them, one at a time.
///
/// Sequential by design: the TFLite/ONNX services are singletons whose
/// interpreters are not re-entrant, and all inference runs on the UI isolate.
class BatchProcessingRunner {
  BatchProcessingRunner({
    DroneBatchService? batchService,
    PlantService? plantService,
    LocalGuestService? localGuestService,
  }) : _batchService = batchService ?? DroneBatchService(),
       _plantService = plantService ?? PlantService(),
       _localGuestService = localGuestService ?? LocalGuestService();

  final DroneBatchService _batchService;
  final PlantService _plantService;
  final LocalGuestService _localGuestService;

  final StreamController<BatchProgress> _progressController =
      StreamController<BatchProgress>.broadcast();

  bool _cancelled = false;
  bool _disposed = false;

  String? _currentBatchId;
  String? _currentParentPlantId;

  Stream<BatchProgress> get progress => _progressController.stream;

  /// Requests a stop. The leaf in flight finishes first; nothing after it runs.
  void cancel() => _cancelled = true;

  void dispose() {
    _disposed = true;
    _progressController.close();
  }

  void _emit(BatchProgress value) {
    if (_disposed || _progressController.isClosed) return;
    _progressController.add(value);
  }

  bool get _isGuest => _localGuestService.isLocalGuestMode();

  /// Processes every label in [request] and returns the finished batch.
  Future<DroneBatchModel> run(BatchSegmentationRequest request) async {
    var batch = await _batchService.createFromRequest(request);
    _currentBatchId = batch.batchId;
    _currentParentPlantId = batch.parentPlantId;

    // Flag the parent up front, not just on completion: if the batch is
    // interrupted, the drone photo must still be recognised as a batch parent
    // rather than showing up as an ordinary pending single-image card.
    await _markParentPlantStarted(batch);

    _emit(
      BatchProgress(
        batchId: batch.batchId,
        total: batch.totalCount,
        completed: 0,
        failed: 0,
        stageMessage: 'Preparing image',
        batch: batch,
      ),
    );

    OrientedImage oriented;
    try {
      final bytes = await _originalImageBytes(request);
      oriented = decodeOriented(
        bytes,
        expectedWidth: request.imageWidth,
        expectedHeight: request.imageHeight,
      );
    } catch (e, st) {
      logger.e('[BatchProcessingRunner] Could not read drone image: $e\n$st');
      final failedBatch = await _batchService.finalizeBatch(
        batch,
        status: BatchStatus.error,
        errorMessage: 'Could not read the drone image: $e',
      );
      _emit(
        BatchProgress(
          batchId: batch.batchId,
          total: batch.totalCount,
          completed: 0,
          failed: 0,
          done: true,
          batch: failedBatch,
          error: e,
        ),
      );
      return failedBatch;
    }

    // Pixel masks are indexed against exact image dimensions, so a mismatch
    // would silently mask the wrong pixels. Rectangles tolerate it (they are
    // resolved against whatever was decoded); masks must not.
    if (request.hasMasks && !oriented.dimensionsMatched) {
      final message =
          'The masks were made for a ${request.imageWidth}x'
          '${request.imageHeight} image, but the drone image decoded to '
          '${oriented.width}x${oriented.height}.';
      logger.e('[BatchProcessingRunner] $message');
      final failedBatch = await _batchService.finalizeBatch(
        batch,
        status: BatchStatus.error,
        errorMessage: message,
      );
      _emit(
        BatchProgress(
          batchId: batch.batchId,
          total: batch.totalCount,
          completed: 0,
          failed: 0,
          done: true,
          batch: failedBatch,
          error: message,
        ),
      );
      return failedBatch;
    }

    final segModel = await LeafAnalysisPipeline.defaultSegModel();

    for (final entry in List<BatchLeafEntry>.of(batch.leaves)) {
      if (_cancelled) break;

      _emit(
        BatchProgress(
          batchId: batch.batchId,
          total: batch.totalCount,
          completed: batch.completedCount,
          failed: batch.failedCount,
          currentIndex: entry.index,
          stageMessage: 'Analyzing ${entry.displayName}',
          batch: batch,
        ),
      );

      BatchLeafEntry result;
      try {
        result = await _processLeaf(
          entry: entry,
          oriented: oriented,
          segModel: segModel,
          mask: request.masks?[entry.index],
        );
      } catch (e, st) {
        // One bad leaf must never sink the batch.
        logger.e(
          '[BatchProcessingRunner] ${entry.displayName} failed: $e\n$st',
        );
        result = entry.copyWith(
          status: LeafStatus.error,
          errorMessage: e.toString(),
        );
      }

      batch = (await _batchService.upsertLeafEntry(batch.batchId, result)) ??
          batch.withLeaf(result);

      _emit(
        BatchProgress(
          batchId: batch.batchId,
          total: batch.totalCount,
          completed: batch.completedCount,
          failed: batch.failedCount,
          currentIndex: entry.index,
          stageMessage: 'Finished ${entry.displayName}',
          batch: batch,
        ),
      );

      // Give the UI a frame to paint the new count before the next leaf hogs
      // the isolate again.
      await Future<void>.delayed(Duration.zero);
    }

    final summary = BatchSummary.fromEntries(batch.leaves);
    final recommendation = await _batchRecommendation(summary);

    final status =
        _cancelled
            ? BatchStatus.cancelled
            : (batch.failedCount == 0
                ? BatchStatus.completed
                : BatchStatus.partial);

    batch = await _batchService.finalizeBatch(
      batch,
      status: status,
      summary: summary.copyWith(recommendation: recommendation),
    );

    await _markParentPlant(batch);

    _emit(
      BatchProgress(
        batchId: batch.batchId,
        total: batch.totalCount,
        completed: batch.completedCount,
        failed: batch.failedCount,
        done: true,
        cancelled: _cancelled,
        stageMessage: 'Done',
        batch: batch,
      ),
    );

    return batch;
  }

  /// The request carries the picked bytes, so the happy path needs no I/O.
  Future<Uint8List> _originalImageBytes(BatchSegmentationRequest request) async {
    if (request.localImageBytes.isNotEmpty) return request.localImageBytes;

    final src = request.imageUrl;
    if (src.isEmpty) {
      throw Exception('No image bytes and no image URL in the batch request');
    }
    if (isLocalFilesystemPath(src)) {
      return File(toLocalFilePath(src)).readAsBytes();
    }
    final resp = await http
        .get(Uri.parse(src))
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('Failed to download drone image (${resp.statusCode})');
    }
    return resp.bodyBytes;
  }

  /// When [mask] is supplied the leaf image is the masked bbox crop and the
  /// app's own segmentation model is skipped — a SAM mask is already
  /// segmentation output.
  Future<BatchLeafEntry> _processLeaf({
    required BatchLeafEntry entry,
    required OrientedImage oriented,
    required String segModel,
    LeafMask? mask,
  }) async {
    final rect =
        mask != null
            ? clampRectToImage(mask.bbox, oriented.width, oriented.height)
            : denormalizeRect(entry.region, oriented.width, oriented.height);
    if (!isUsableCrop(rect)) {
      return entry.copyWith(
        status: LeafStatus.error,
        errorMessage:
            'Region is too small to analyze '
            '(${rect.width}x${rect.height} px, minimum $kMinCropPixels)',
      );
    }

    final cropBytes =
        mask != null
            ? maskedLeafJpeg(oriented.image, mask)
            : cropLeafJpeg(oriented.image, rect);

    // `.jpg` matters: StorageUtils.isValidImageExtension only accepts jpg/jpeg/png.
    final cropFile = await LeafAnalysisPipeline.writeTempImage(
      cropBytes,
      prefix: 'leaf_${entry.index + 1}',
      extension: 'jpg',
    );

    Map<String, dynamic> created;
    try {
      // runAnalysis: false — the pipeline below does the inference, so the
      // upload path must not also run the single-image analysis.
      created = await _plantService.uploadAndAnalyzeImage(
        image: XFile(cropFile.path),
        notes: 'Leaf ${entry.index + 1} of drone image',
        runAnalysis: false,
      );
    } finally {
      unawaited(_deleteQuietly(cropFile));
    }

    final leafPlantId = created['plantId'] as String;
    final leafImageId = created['imageId'] as String;
    final croppedImageUrl = created['downloadUrl'] as String;

    final outcome = await LeafAnalysisPipeline.runFull(
      imageBytes: cropBytes,
      plantId: leafPlantId,
      imageId: leafImageId,
      segModel: segModel,
      skipSegmentation: mask != null,
    );

    // The masked crop *is* the segmentation output, so it doubles as the
    // segmentation image rather than being uploaded a second time. Note this
    // deliberately does not touch `images/{imageId}.processedUrls`: the delete
    // path walks that map and would remove the leaf's only stored image.
    final segmentationUrl =
        mask != null ? croppedImageUrl : outcome.segmentationUrl;

    final detection = outcome.detection;
    if (detection == null) {
      await _writePlantAnalysis(
        plantId: leafPlantId,
        status: 'error',
        analysis: {
          'analysisError':
              outcome.error?.toString() ?? 'Analysis returned no result',
          ..._batchMarkers(entry),
        },
      );
      return entry.copyWith(
        leafPlantId: leafPlantId,
        leafImageId: leafImageId,
        croppedImageUrl: croppedImageUrl,
        segmentationUrl: segmentationUrl,
        plantSpecies: outcome.species?.species,
        status: LeafStatus.error,
        errorMessage:
            outcome.error?.toString() ?? 'Analysis returned no result',
      );
    }

    final analysis = <String, dynamic>{
      'detectedDisease': detection.diseaseName,
      'confidence': detection.confidence,
      'detectionTimestamp': DateTime.now().toIso8601String(),
      if (segmentationUrl != null) 'segmentationUrl': segmentationUrl,
      if (outcome.species != null) 'plantSpecies': outcome.species!.species,
      if (outcome.species?.confidence != null)
        'plantSpeciesConfidence': outcome.species!.confidence,
      // 'sam' tells SegmentPage this leaf was masked externally, so it must not
      // offer to re-run the local segmentation models over it.
      'model': mask != null ? 'sam' : segModel,
      if (mask != null) 'segmentationSource': 'sam',
      'manuallyOverridden': false,
      'source': 'batch',
      'analysisStage': 3,
      'analysisCompleted': true,
      // Placeholder advice so the leaf counts as complete on the home screen
      // without the batch making one LLM call per leaf. SegmentPage upgrades
      // this to a real answer when the leaf is opened.
      'recommendation': _placeholderRecommendation(detection.diseaseName),
      'recommendationSource': 'fallback',
      ..._batchMarkers(entry),
    };

    await _writePlantAnalysis(
      plantId: leafPlantId,
      status: 'completed',
      analysis: analysis,
    );
    await _plantService.saveImageAnalysisResult(
      plantId: leafPlantId,
      imageId: leafImageId,
      analysis: analysis,
    );

    return entry.copyWith(
      leafPlantId: leafPlantId,
      leafImageId: leafImageId,
      croppedImageUrl: croppedImageUrl,
      status: LeafStatus.completed,
      detectedDisease: detection.diseaseName,
      confidence: detection.confidence,
      plantSpecies: outcome.species?.species,
      plantSpeciesConfidence: outcome.species?.confidence,
      segmentationUrl: segmentationUrl,
    );
  }

  /// Keys that tie a child plant back to its batch.
  Map<String, dynamic> _batchMarkers(BatchLeafEntry entry) {
    return {
      if (_currentBatchId != null) 'batchId': _currentBatchId,
      if (_currentParentPlantId != null)
        'parentPlantId': _currentParentPlantId,
      'labelId': entry.labelId,
      'leafIndex': entry.index,
      'leafRegion': entry.region.toJson(),
    };
  }

  /// Writes `analysisResults` for a plant, honouring guest vs Firebase.
  Future<void> _writePlantAnalysis({
    required String plantId,
    required String status,
    required Map<String, dynamic> analysis,
  }) async {
    if (_isGuest) {
      await _localGuestService.mergeAnalysisResultsIntoPlant(
        plantId: plantId,
        status: status,
        patch: analysis,
      );
      return;
    }
    await FirebaseFirestore.instance.collection('plants').doc(plantId).update({
      'status': status,
      'analysisResults': analysis,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markParentPlantStarted(DroneBatchModel batch) async {
    try {
      await _writePlantAnalysis(
        plantId: batch.parentPlantId,
        status: 'processing',
        analysis: {
          'isBatchParent': true,
          'batchId': batch.batchId,
          'leafCount': batch.totalCount,
          'batchStatus': batch.status,
        },
      );
    } catch (e, st) {
      logger.w('[BatchProcessingRunner] Could not flag parent plant: $e\n$st');
    }
  }

  /// Flags the drone image's own plant so the home list renders it as a batch
  /// card instead of opening the single-image result page.
  Future<void> _markParentPlant(DroneBatchModel batch) async {
    final summary = batch.summary;
    try {
      await _writePlantAnalysis(
        plantId: batch.parentPlantId,
        status: 'completed',
        analysis: {
          'isBatchParent': true,
          'batchId': batch.batchId,
          'leafCount': batch.totalCount,
          'completedLeafCount': batch.completedCount,
          'failedLeafCount': batch.failedCount,
          if (summary != null) 'healthyCount': summary.healthyCount,
          if (summary != null) 'diseasedCount': summary.diseasedCount,
          if (summary?.dominantDisease != null)
            'dominantDisease': summary!.dominantDisease,
          if (summary?.recommendation != null)
            'recommendation': summary!.recommendation,
          'detectionTimestamp': DateTime.now().toIso8601String(),
          'batchStatus': batch.status,
        },
      );
    } catch (e, st) {
      logger.w('[BatchProcessingRunner] Could not mark parent plant: $e\n$st');
    }
  }

  /// Per-leaf placeholder advice, from the offline table where possible.
  String _placeholderRecommendation(String diseaseName) {
    final specific = fallbackSuggestionForDisease(diseaseName);
    if (specific != null && specific.isNotEmpty) return specific;

    final pretty = UIUtils.formatDiseaseName(diseaseName);
    if (isHealthyDiseaseLabel(diseaseName)) {
      return 'This leaf appears healthy. Keep monitoring regularly, water at the '
          'base, and maintain good spacing and airflow. Open this result for a '
          'detailed AI suggestion.';
    }
    return 'Detected $pretty. Isolate affected leaves, avoid overhead watering, '
        'and check nearby plants for the same symptoms. Open this result for a '
        'detailed AI suggestion.';
  }

  /// One LLM call for the whole batch, with a locally-composed fallback.
  Future<String> _batchRecommendation(BatchSummary summary) async {
    final local = _localBatchSummaryText(summary);
    if (summary.analyzedCount == 0) return local;

    try {
      final breakdown = summary.diseaseCounts.entries
          .map((e) => '${UIUtils.formatDiseaseName(e.key)}: ${e.value}')
          .join(', ');
      final prompt =
          'A drone photo of a crop was split into ${summary.leafCount} leaf '
          'regions and analyzed. Results: $breakdown. '
          '${summary.healthyCount} healthy, ${summary.diseasedCount} diseased. '
          'In 3-4 sentences, summarise the overall health of this area and give '
          'the most important practical actions the grower should take next.';

      final answer = await GeminiService()
          .getAnswer(
            prompt,
            preferredModel: 'gemma-3-27b-it',
            isPlantRelated: true,
          )
          .timeout(const Duration(seconds: 30));

      if (answer.trim().isEmpty || answer.startsWith('Error:')) return local;
      return answer.trim();
    } catch (e) {
      logger.w('[BatchProcessingRunner] Batch recommendation failed: $e');
      return local;
    }
  }

  String _localBatchSummaryText(BatchSummary summary) {
    if (summary.analyzedCount == 0) {
      return 'No leaves could be analyzed in this drone image. Try drawing '
          'larger regions around individual leaves and processing again.';
    }
    final buffer = StringBuffer()
      ..write(
        '${summary.analyzedCount} of ${summary.leafCount} labelled regions were '
        'analyzed: ${summary.healthyCount} healthy and ${summary.diseasedCount} '
        'showing disease. ',
      );
    final dominant = summary.dominantDisease;
    if (dominant != null) {
      buffer.write(
        'The most common problem is ${UIUtils.formatDiseaseName(dominant)}. '
        'Inspect those areas first, remove badly affected leaves, avoid '
        'overhead watering, and keep spacing open for airflow. ',
      );
    } else {
      buffer.write(
        'No disease was detected in this area. Keep monitoring regularly and '
        'maintain consistent watering and spacing. ',
      );
    }
    buffer.write('Open individual leaves for detailed advice.');
    return buffer.toString();
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
