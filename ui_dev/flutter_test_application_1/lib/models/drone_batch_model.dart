import 'package:flutter_test_application_1/data/disease_labels.dart';
import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';

/// Whether [plant] is the drone image that owns a batch rather than a normal
/// single-image record.
///
/// Batch parents are excluded from the plant lists because they are surfaced by
/// `BatchCardWidget` instead — opening one in `SegmentPage` would show an empty
/// single-image result for a photo full of leaves.
bool isBatchParentPlant(PlantModel plant) {
  return plant.analysisResults?['isBatchParent'] == true;
}

/// The batch a leaf belongs to, or null for a normal single-image record.
String? batchIdOfLeafPlant(PlantModel plant) {
  final ar = plant.analysisResults;
  if (ar == null || ar['isBatchParent'] == true) return null;
  final id = ar['batchId'];
  return id is String && id.isNotEmpty ? id : null;
}

/// Batch lifecycle states.
class BatchStatus {
  BatchStatus._();

  static const String processing = 'processing';

  /// Every leaf analyzed successfully.
  static const String completed = 'completed';

  /// Finished, but at least one leaf failed.
  static const String partial = 'partial';

  /// Stopped by the user; completed leaves are retained.
  static const String cancelled = 'cancelled';

  /// The batch itself failed (e.g. the source image could not be decoded).
  static const String error = 'error';
}

/// Per-leaf lifecycle states.
class LeafStatus {
  LeafStatus._();

  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String completed = 'completed';
  static const String error = 'error';
}

/// One labelled region and whatever the pipeline produced for it.
class BatchLeafEntry {
  const BatchLeafEntry({
    required this.labelId,
    required this.index,
    required this.region,
    this.leafPlantId,
    this.leafImageId,
    this.croppedImageUrl,
    this.status = LeafStatus.pending,
    this.detectedDisease,
    this.confidence,
    this.plantSpecies,
    this.plantSpeciesConfidence,
    this.segmentationUrl,
    this.errorMessage,
  });

  /// Matches the `label_N` ids in [BatchSegmentationRequest.toJson].
  final String labelId;
  final int index;
  final NormalizedLabelRect region;

  /// The child `PlantModel` this leaf became — what `SegmentPage` opens.
  final String? leafPlantId;
  final String? leafImageId;
  final String? croppedImageUrl;

  final String status;
  final String? detectedDisease;
  final double? confidence;
  final String? plantSpecies;
  final double? plantSpeciesConfidence;
  final String? segmentationUrl;
  final String? errorMessage;

  bool get isHealthy => isHealthyDiseaseLabel(detectedDisease);
  bool get isCompleted => status == LeafStatus.completed;
  bool get isFailed => status == LeafStatus.error;

  /// 1-based label for display ("Leaf 3").
  String get displayName => 'Leaf ${index + 1}';

  Map<String, dynamic> toMap() {
    return {
      'labelId': labelId,
      'index': index,
      'region': region.toJson(),
      'leafPlantId': leafPlantId,
      'leafImageId': leafImageId,
      'croppedImageUrl': croppedImageUrl,
      'status': status,
      'detectedDisease': detectedDisease,
      'confidence': confidence,
      'plantSpecies': plantSpecies,
      'plantSpeciesConfidence': plantSpeciesConfidence,
      'segmentationUrl': segmentationUrl,
      'errorMessage': errorMessage,
    };
  }

  factory BatchLeafEntry.fromMap(Map<String, dynamic> map) {
    return BatchLeafEntry(
      labelId: map['labelId'] as String,
      index: (map['index'] as num).toInt(),
      region: NormalizedLabelRect.fromJson(
        Map<String, dynamic>.from(map['region'] as Map),
      ),
      leafPlantId: map['leafPlantId'] as String?,
      leafImageId: map['leafImageId'] as String?,
      croppedImageUrl: map['croppedImageUrl'] as String?,
      status: map['status'] as String? ?? LeafStatus.pending,
      detectedDisease: map['detectedDisease'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble(),
      plantSpecies: map['plantSpecies'] as String?,
      plantSpeciesConfidence:
          (map['plantSpeciesConfidence'] as num?)?.toDouble(),
      segmentationUrl: map['segmentationUrl'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  BatchLeafEntry copyWith({
    String? leafPlantId,
    String? leafImageId,
    String? croppedImageUrl,
    String? status,
    String? detectedDisease,
    double? confidence,
    String? plantSpecies,
    double? plantSpeciesConfidence,
    String? segmentationUrl,
    String? errorMessage,
  }) {
    return BatchLeafEntry(
      labelId: labelId,
      index: index,
      region: region,
      leafPlantId: leafPlantId ?? this.leafPlantId,
      leafImageId: leafImageId ?? this.leafImageId,
      croppedImageUrl: croppedImageUrl ?? this.croppedImageUrl,
      status: status ?? this.status,
      detectedDisease: detectedDisease ?? this.detectedDisease,
      confidence: confidence ?? this.confidence,
      plantSpecies: plantSpecies ?? this.plantSpecies,
      plantSpeciesConfidence:
          plantSpeciesConfidence ?? this.plantSpeciesConfidence,
      segmentationUrl: segmentationUrl ?? this.segmentationUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Aggregate view of a finished batch, shown on the drone result page.
class BatchSummary {
  const BatchSummary({
    required this.leafCount,
    required this.analyzedCount,
    required this.healthyCount,
    required this.diseasedCount,
    required this.diseaseCounts,
    required this.speciesCounts,
    this.dominantDisease,
    this.averageConfidence,
    this.recommendation,
  });

  final int leafCount;

  /// Leaves that produced a disease result (failures excluded).
  final int analyzedCount;
  final int healthyCount;
  final int diseasedCount;

  /// Raw disease label -> number of leaves, descending by count.
  final Map<String, int> diseaseCounts;
  final Map<String, int> speciesCounts;

  /// Most common non-healthy disease, or null when nothing is diseased.
  final String? dominantDisease;
  final double? averageConfidence;
  final String? recommendation;

  /// Aggregates the completed entries. Failed and pending leaves count towards
  /// [leafCount] but not towards [analyzedCount] or any of the breakdowns.
  factory BatchSummary.fromEntries(
    List<BatchLeafEntry> entries, {
    String? recommendation,
  }) {
    final diseaseCounts = <String, int>{};
    final speciesCounts = <String, int>{};
    var healthy = 0;
    var diseased = 0;
    var analyzed = 0;
    var confidenceSum = 0.0;
    var confidenceCount = 0;

    for (final entry in entries) {
      final disease = entry.detectedDisease;
      if (!entry.isCompleted || disease == null || disease.isEmpty) continue;

      analyzed++;
      diseaseCounts[disease] = (diseaseCounts[disease] ?? 0) + 1;

      final species = entry.plantSpecies;
      if (species != null && species.isNotEmpty) {
        speciesCounts[species] = (speciesCounts[species] ?? 0) + 1;
      }

      if (entry.isHealthy) {
        healthy++;
      } else {
        diseased++;
      }

      final confidence = entry.confidence;
      if (confidence != null && confidence.isFinite) {
        confidenceSum += confidence;
        confidenceCount++;
      }
    }

    String? dominant;
    var dominantCount = 0;
    for (final e in diseaseCounts.entries) {
      if (isHealthyDiseaseLabel(e.key)) continue;
      if (e.value > dominantCount) {
        dominant = e.key;
        dominantCount = e.value;
      }
    }

    return BatchSummary(
      leafCount: entries.length,
      analyzedCount: analyzed,
      healthyCount: healthy,
      diseasedCount: diseased,
      diseaseCounts: _sortedByCountDescending(diseaseCounts),
      speciesCounts: _sortedByCountDescending(speciesCounts),
      dominantDisease: dominant,
      averageConfidence:
          confidenceCount == 0 ? null : confidenceSum / confidenceCount,
      recommendation: recommendation,
    );
  }

  static Map<String, int> _sortedByCountDescending(Map<String, int> counts) {
    final entries =
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map<String, int>.fromEntries(entries);
  }

  BatchSummary copyWith({String? recommendation}) {
    return BatchSummary(
      leafCount: leafCount,
      analyzedCount: analyzedCount,
      healthyCount: healthyCount,
      diseasedCount: diseasedCount,
      diseaseCounts: diseaseCounts,
      speciesCounts: speciesCounts,
      dominantDisease: dominantDisease,
      averageConfidence: averageConfidence,
      recommendation: recommendation ?? this.recommendation,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leafCount': leafCount,
      'analyzedCount': analyzedCount,
      'healthyCount': healthyCount,
      'diseasedCount': diseasedCount,
      'diseaseCounts': diseaseCounts,
      'speciesCounts': speciesCounts,
      'dominantDisease': dominantDisease,
      'averageConfidence': averageConfidence,
      'recommendation': recommendation,
    };
  }

  factory BatchSummary.fromMap(Map<String, dynamic> map) {
    return BatchSummary(
      leafCount: (map['leafCount'] as num?)?.toInt() ?? 0,
      analyzedCount: (map['analyzedCount'] as num?)?.toInt() ?? 0,
      healthyCount: (map['healthyCount'] as num?)?.toInt() ?? 0,
      diseasedCount: (map['diseasedCount'] as num?)?.toInt() ?? 0,
      diseaseCounts: _intMap(map['diseaseCounts']),
      speciesCounts: _intMap(map['speciesCounts']),
      dominantDisease: map['dominantDisease'] as String?,
      averageConfidence: (map['averageConfidence'] as num?)?.toDouble(),
      recommendation: map['recommendation'] as String?,
    );
  }

  static Map<String, int> _intMap(Object? raw) {
    if (raw is! Map) return <String, int>{};
    return raw.map(
      (key, value) => MapEntry('$key', (value as num).toInt()),
    );
  }
}

/// Result record for a drone image processed as a batch of labelled leaves.
///
/// Sits alongside the drone image's own `PlantModel` (`batchId == parentPlantId`)
/// and links out to one child plant per leaf.
class DroneBatchModel {
  const DroneBatchModel({
    required this.batchId,
    required this.userId,
    required this.parentPlantId,
    required this.parentImageId,
    required this.originalImageUrl,
    required this.imageWidth,
    required this.imageHeight,
    required this.createdAt,
    required this.status,
    required this.leaves,
    this.updatedAt,
    this.summary,
    this.errorMessage,
    this.segmentationSource = segmentationSourceManual,
  });

  /// Regions drawn by hand as rectangles.
  static const String segmentationSourceManual = 'manual';

  /// Regions derived from an uploaded SAM mask file.
  static const String segmentationSourceSam = 'sam';

  final String batchId;
  final String userId;
  final String parentPlantId;
  final String parentImageId;

  /// Either an `https://` download URL or a `file://` URI, matching the rest of
  /// the app's polymorphic image-source convention.
  final String originalImageUrl;
  final int imageWidth;
  final int imageHeight;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status;
  final List<BatchLeafEntry> leaves;
  final BatchSummary? summary;
  final String? errorMessage;

  /// Which flow produced the regions: [segmentationSourceManual] or
  /// [segmentationSourceSam].
  final String segmentationSource;

  int get totalCount => leaves.length;
  int get completedCount => leaves.where((l) => l.isCompleted).length;
  int get failedCount => leaves.where((l) => l.isFailed).length;
  int get finishedCount => completedCount + failedCount;

  bool get isFinished =>
      status == BatchStatus.completed ||
      status == BatchStatus.partial ||
      status == BatchStatus.cancelled ||
      status == BatchStatus.error;

  double get progress => totalCount == 0 ? 0 : finishedCount / totalCount;

  /// Creates the initial record, with one pending entry per label.
  factory DroneBatchModel.fromRequest(
    BatchSegmentationRequest request, {
    required String userId,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return DroneBatchModel(
      batchId: request.plantId,
      userId: userId,
      parentPlantId: request.plantId,
      parentImageId: request.imageId,
      originalImageUrl: request.imageUrl,
      imageWidth: request.imageWidth,
      imageHeight: request.imageHeight,
      createdAt: now,
      status: BatchStatus.processing,
      segmentationSource:
          request.hasMasks ? segmentationSourceSam : segmentationSourceManual,
      leaves: [
        for (var i = 0; i < request.labels.length; i++)
          BatchLeafEntry(
            labelId: 'label_${i + 1}',
            index: i,
            region: request.labels[i],
          ),
      ],
    );
  }

  DroneBatchModel copyWith({
    DateTime? updatedAt,
    String? status,
    List<BatchLeafEntry>? leaves,
    BatchSummary? summary,
    String? errorMessage,
  }) {
    return DroneBatchModel(
      batchId: batchId,
      userId: userId,
      parentPlantId: parentPlantId,
      parentImageId: parentImageId,
      originalImageUrl: originalImageUrl,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      leaves: leaves ?? this.leaves,
      summary: summary ?? this.summary,
      errorMessage: errorMessage ?? this.errorMessage,
      segmentationSource: segmentationSource,
    );
  }

  /// Replaces the entry at [entry]'s index, leaving the rest untouched.
  DroneBatchModel withLeaf(BatchLeafEntry entry) {
    final next = List<BatchLeafEntry>.of(leaves);
    final at = next.indexWhere((l) => l.labelId == entry.labelId);
    if (at == -1) {
      next.add(entry);
    } else {
      next[at] = entry;
    }
    return copyWith(leaves: next, updatedAt: DateTime.now());
  }

  /// Dates are stored as ISO-8601 strings so the same map works for both
  /// Firestore and the SharedPreferences JSON used in guest mode.
  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'userId': userId,
      'parentPlantId': parentPlantId,
      'parentImageId': parentImageId,
      'originalImageUrl': originalImageUrl,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'status': status,
      'leaves': leaves.map((l) => l.toMap()).toList(),
      'summary': summary?.toMap(),
      'errorMessage': errorMessage,
      'segmentationSource': segmentationSource,
    };
  }

  factory DroneBatchModel.fromMap(Map<String, dynamic> map) {
    return DroneBatchModel(
      batchId: map['batchId'] as String,
      userId: map['userId'] as String,
      parentPlantId: map['parentPlantId'] as String,
      parentImageId: map['parentImageId'] as String,
      originalImageUrl: map['originalImageUrl'] as String? ?? '',
      imageWidth: (map['imageWidth'] as num?)?.toInt() ?? 0,
      imageHeight: (map['imageHeight'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt:
          map['updatedAt'] == null
              ? null
              : DateTime.parse(map['updatedAt'] as String),
      status: map['status'] as String,
      leaves: [
        for (final raw in (map['leaves'] as List<dynamic>? ?? const []))
          BatchLeafEntry.fromMap(Map<String, dynamic>.from(raw as Map)),
      ],
      summary:
          map['summary'] == null
              ? null
              : BatchSummary.fromMap(
                Map<String, dynamic>.from(map['summary'] as Map),
              ),
      errorMessage: map['errorMessage'] as String?,
      // Records written before the SAM flow existed are all manual.
      segmentationSource:
          map['segmentationSource'] as String? ?? segmentationSourceManual,
    );
  }
}
