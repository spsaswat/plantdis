import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/drone_batch_model.dart';
import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';

BatchLeafEntry _leaf(
  int index, {
  String status = LeafStatus.completed,
  String? disease,
  double? confidence,
  String? species,
}) {
  return BatchLeafEntry(
    labelId: 'label_${index + 1}',
    index: index,
    region: NormalizedLabelRect(
      x: 0.1 * index,
      y: 0.1,
      width: 0.1,
      height: 0.1,
    ),
    leafPlantId: 'plant_$index',
    leafImageId: 'img_$index',
    croppedImageUrl: 'file:///leaf_$index.jpg',
    status: status,
    detectedDisease: disease,
    confidence: confidence,
    plantSpecies: species,
  );
}

BatchSegmentationRequest _request({int labels = 2}) {
  return BatchSegmentationRequest(
    imageId: 'img_drone',
    plantId: 'plant_drone',
    imageUrl: 'https://example.test/drone.jpg',
    labels: [
      for (var i = 0; i < labels; i++)
        NormalizedLabelRect(x: 0.1 * i, y: 0.2, width: 0.15, height: 0.3),
    ],
    localImageBytes: Uint8List(0),
    imageWidth: 4000,
    imageHeight: 3000,
  );
}

void main() {
  group('DroneBatchModel.fromRequest', () {
    test('creates one pending entry per label, keyed to the drone plant', () {
      final batch = DroneBatchModel.fromRequest(
        _request(labels: 3),
        userId: 'user_1',
      );

      expect(batch.batchId, 'plant_drone');
      expect(batch.parentPlantId, 'plant_drone');
      expect(batch.parentImageId, 'img_drone');
      expect(batch.status, BatchStatus.processing);
      expect(batch.totalCount, 3);
      expect(batch.completedCount, 0);
      expect(batch.leaves.map((l) => l.labelId), [
        'label_1',
        'label_2',
        'label_3',
      ]);
      expect(batch.leaves.every((l) => l.status == LeafStatus.pending), isTrue);
    });

    test('records which flow produced the regions', () {
      final manual = DroneBatchModel.fromRequest(_request(), userId: 'user_1');
      expect(manual.segmentationSource, DroneBatchModel.segmentationSourceManual);

      final sam = DroneBatchModel.fromRequest(
        BatchSegmentationRequest(
          imageId: 'img_drone',
          plantId: 'plant_drone',
          imageUrl: 'https://example.test/drone.jpg',
          labels: const [
            NormalizedLabelRect(x: 0, y: 0, width: 0.1, height: 0.1),
          ],
          localImageBytes: Uint8List(0),
          imageWidth: 4000,
          imageHeight: 3000,
          masks: [
            LeafMask(
              left: 0,
              top: 0,
              width: 2,
              height: 2,
              bytes: Uint8List(4)..fillRange(0, 4, 1),
            ),
          ],
        ),
        userId: 'user_1',
      );
      expect(sam.segmentationSource, DroneBatchModel.segmentationSourceSam);
    });
  });

  group('round trip', () {
    test('survives toMap/fromMap with leaves and summary', () {
      final original = DroneBatchModel.fromRequest(
        _request(),
        userId: 'user_1',
      )
          .withLeaf(
            _leaf(0, disease: 'Tomato___Late_blight', confidence: 0.9,
                species: 'tomato'),
          )
          .copyWith(
            status: BatchStatus.completed,
            summary: BatchSummary.fromEntries([
              _leaf(0, disease: 'Tomato___Late_blight', confidence: 0.9),
            ], recommendation: 'Act quickly.'),
          );

      final restored = DroneBatchModel.fromMap(original.toMap());

      expect(restored.batchId, original.batchId);
      expect(restored.status, BatchStatus.completed);
      expect(restored.imageWidth, 4000);
      expect(restored.leaves.length, original.leaves.length);
      expect(restored.leaves.first.detectedDisease, 'Tomato___Late_blight');
      expect(restored.leaves.first.confidence, closeTo(0.9, 0.0001));
      expect(restored.leaves.first.plantSpecies, 'tomato');
      expect(restored.leaves.first.region.width, closeTo(0.1, 0.0001));
      expect(restored.summary?.recommendation, 'Act quickly.');
      expect(restored.summary?.diseasedCount, 1);
    });

    test('reads records written before the SAM flow existed as manual', () {
      final legacy = DroneBatchModel.fromRequest(
        _request(),
        userId: 'user_1',
      ).toMap()..remove('segmentationSource');

      expect(
        DroneBatchModel.fromMap(legacy).segmentationSource,
        DroneBatchModel.segmentationSourceManual,
      );
    });
  });

  group('withLeaf', () {
    test('replaces the matching entry instead of appending', () {
      final batch = DroneBatchModel.fromRequest(_request(), userId: 'user_1');

      final updated = batch.withLeaf(
        _leaf(0, disease: 'Apple___healthy', confidence: 0.8),
      );

      expect(updated.totalCount, 2);
      expect(updated.leaves.first.status, LeafStatus.completed);
      expect(updated.leaves[1].status, LeafStatus.pending);
    });
  });

  group('counts', () {
    test('separates completed, failed and still-pending leaves', () {
      final batch = DroneBatchModel.fromRequest(
        _request(labels: 3),
        userId: 'user_1',
      )
          .withLeaf(_leaf(0, disease: 'Apple___healthy', confidence: 0.8))
          .withLeaf(_leaf(1, status: LeafStatus.error));

      expect(batch.completedCount, 1);
      expect(batch.failedCount, 1);
      expect(batch.finishedCount, 2);
      expect(batch.progress, closeTo(2 / 3, 0.0001));
    });
  });

  group('BatchSummary.fromEntries', () {
    test('aggregates health, species and the dominant disease', () {
      final summary = BatchSummary.fromEntries([
        _leaf(0, disease: 'Tomato___Late_blight', confidence: 0.9,
            species: 'tomato'),
        _leaf(1, disease: 'Tomato___Late_blight', confidence: 0.7,
            species: 'tomato'),
        _leaf(2, disease: 'Tomato___Early_blight', confidence: 0.8,
            species: 'tomato'),
        _leaf(3, disease: 'Tomato___healthy', confidence: 0.6,
            species: 'tomato'),
      ]);

      expect(summary.leafCount, 4);
      expect(summary.analyzedCount, 4);
      expect(summary.healthyCount, 1);
      expect(summary.diseasedCount, 3);
      expect(summary.dominantDisease, 'Tomato___Late_blight');
      expect(summary.diseaseCounts['Tomato___Late_blight'], 2);
      expect(summary.speciesCounts['tomato'], 4);
      expect(summary.averageConfidence, closeTo(0.75, 0.0001));
    });

    test('never picks a healthy label as the dominant disease', () {
      final summary = BatchSummary.fromEntries([
        _leaf(0, disease: 'Apple___healthy', confidence: 0.9),
        _leaf(1, disease: 'Apple___healthy', confidence: 0.9),
        _leaf(2, disease: 'Apple___Black_rot', confidence: 0.5),
      ]);

      expect(summary.healthyCount, 2);
      expect(summary.dominantDisease, 'Apple___Black_rot');
    });

    test('leaves dominantDisease null when everything is healthy', () {
      final summary = BatchSummary.fromEntries([
        _leaf(0, disease: 'Apple___healthy', confidence: 0.9),
      ]);

      expect(summary.dominantDisease, isNull);
      expect(summary.diseasedCount, 0);
    });

    test('excludes failed and pending leaves from the breakdowns', () {
      final summary = BatchSummary.fromEntries([
        _leaf(0, disease: 'Apple___Black_rot', confidence: 0.9),
        _leaf(1, status: LeafStatus.error),
        _leaf(2, status: LeafStatus.pending),
      ]);

      expect(summary.leafCount, 3);
      expect(summary.analyzedCount, 1);
      expect(summary.diseasedCount, 1);
      expect(summary.averageConfidence, closeTo(0.9, 0.0001));
    });

    test('handles an empty batch without dividing by zero', () {
      final summary = BatchSummary.fromEntries([]);

      expect(summary.leafCount, 0);
      expect(summary.analyzedCount, 0);
      expect(summary.averageConfidence, isNull);
      expect(summary.dominantDisease, isNull);
    });
  });

  group('plant helpers', () {
    PlantModel plant(Map<String, dynamic>? analysisResults) {
      return PlantModel(
        plantId: 'p1',
        userId: 'u1',
        createdAt: DateTime(2026, 8, 3),
        status: 'completed',
        images: const ['i1'],
        analysisResults: analysisResults,
      );
    }

    test('identifies batch parents', () {
      expect(isBatchParentPlant(plant({'isBatchParent': true})), isTrue);
      expect(isBatchParentPlant(plant({'batchId': 'b1'})), isFalse);
      expect(isBatchParentPlant(plant(null)), isFalse);
    });

    test('reads the batch id of a leaf but not of a parent', () {
      expect(batchIdOfLeafPlant(plant({'batchId': 'b1'})), 'b1');
      expect(
        batchIdOfLeafPlant(plant({'isBatchParent': true, 'batchId': 'b1'})),
        isNull,
      );
      expect(batchIdOfLeafPlant(plant(null)), isNull);
    });
  });
}
