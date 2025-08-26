import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';

void main() {
  group('PlantModel', () {
    final testDateTime = DateTime(2025, 8, 20, 10, 30, 0);
    final testTimestamp = Timestamp.fromDate(testDateTime);

    test('should create instance with all required fields', () {
      // Arrange & Act
      final plant = PlantModel(
        plantId: 'plant_001',
        userId: 'user_123',
        createdAt: testDateTime,
        status: 'analyzing',
        images: ['img_001', 'img_002'],
        analysisResults: {'disease': 'leaf_spot', 'confidence': 0.85},
      );

      // Assert
      expect(plant.plantId, 'plant_001');
      expect(plant.userId, 'user_123');
      expect(plant.createdAt, testDateTime);
      expect(plant.status, 'analyzing');
      expect(plant.images, ['img_001', 'img_002']);
      expect(plant.analysisResults, {'disease': 'leaf_spot', 'confidence': 0.85});
    });

    test('should create instance with null analysisResults', () {
      // Arrange & Act
      final plant = PlantModel(
        plantId: 'plant_001',
        userId: 'user_123',
        createdAt: testDateTime,
        status: 'pending',
        images: ['img_001'],
      );

      // Assert
      expect(plant.analysisResults, isNull);
    });

    test('should convert to map correctly', () {
      // Arrange
      final plant = PlantModel(
        plantId: 'plant_001',
        userId: 'user_123',
        createdAt: testDateTime,
        status: 'completed',
        images: ['img_001', 'img_002'],
        analysisResults: {'disease': 'healthy', 'confidence': 0.95},
      );

      // Act
      final map = plant.toMap();

      // Assert
      expect(map['plantId'], 'plant_001');
      expect(map['userId'], 'user_123');
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), testDateTime);
      expect(map['status'], 'completed');
      expect(map['images'], ['img_001', 'img_002']);
      expect(map['analysisResults'], {'disease': 'healthy', 'confidence': 0.95});
    });

    test('should convert from map correctly', () {
      // Arrange
      final map = {
        'plantId': 'plant_002',
        'userId': 'user_456',
        'createdAt': testTimestamp,
        'status': 'failed',
        'images': ['img_003'],
        'analysisResults': {'error': 'processing_failed'},
      };

      // Act
      final plant = PlantModel.fromMap(map);

      // Assert
      expect(plant.plantId, 'plant_002');
      expect(plant.userId, 'user_456');
      expect(plant.createdAt, testDateTime);
      expect(plant.status, 'failed');
      expect(plant.images, ['img_003']);
      expect(plant.analysisResults, {'error': 'processing_failed'});
    });

    test('should handle null analysisResults in map conversion', () {
      // Arrange
      final map = {
        'plantId': 'plant_003',
        'userId': 'user_789',
        'createdAt': testTimestamp,
        'status': 'pending',
        'images': <String>[],
        'analysisResults': null,
      };

      // Act
      final plant = PlantModel.fromMap(map);

      // Assert
      expect(plant.analysisResults, isNull);
      expect(plant.images, isEmpty);
    });

    test('should create copy with updated fields using copyWith', () {
      // Arrange
      final originalPlant = PlantModel(
        plantId: 'plant_001',
        userId: 'user_123',
        createdAt: testDateTime,
        status: 'analyzing',
        images: ['img_001'],
      );

      // Act
      final updatedPlant = originalPlant.copyWith(
        status: 'completed',
        images: ['img_001', 'img_002'],
        analysisResults: {'disease': 'leaf_blight', 'confidence': 0.78},
      );

      // Assert
      expect(updatedPlant.plantId, originalPlant.plantId); // unchanged
      expect(updatedPlant.userId, originalPlant.userId); // unchanged
      expect(updatedPlant.createdAt, originalPlant.createdAt); // unchanged
      expect(updatedPlant.status, 'completed'); // changed
      expect(updatedPlant.images, ['img_001', 'img_002']); // changed
      expect(updatedPlant.analysisResults, {'disease': 'leaf_blight', 'confidence': 0.78}); // changed
    });

    test('should preserve original values when copyWith called with null', () {
      // Arrange
      final originalPlant = PlantModel(
        plantId: 'plant_001',
        userId: 'user_123',
        createdAt: testDateTime,
        status: 'analyzing',
        images: ['img_001'],
        analysisResults: {'disease': 'unknown'},
      );

      // Act
      final copiedPlant = originalPlant.copyWith();

      // Assert
      expect(copiedPlant.plantId, originalPlant.plantId);
      expect(copiedPlant.userId, originalPlant.userId);
      expect(copiedPlant.createdAt, originalPlant.createdAt);
      expect(copiedPlant.status, originalPlant.status);
      expect(copiedPlant.images, originalPlant.images);
      expect(copiedPlant.analysisResults, originalPlant.analysisResults);
    });

    test('should handle empty images list', () {
      // Arrange & Act
      final plant = PlantModel(
        plantId: 'plant_empty',
        userId: 'user_123',
        createdAt: testDateTime,
        status: 'pending',
        images: [],
      );

      // Assert
      expect(plant.images, isEmpty);
      expect(plant.images, isA<List<String>>());
    });

    test('should maintain data integrity through map round-trip', () {
      // Arrange
      final originalPlant = PlantModel(
        plantId: 'plant_roundtrip',
        userId: 'user_roundtrip',
        createdAt: testDateTime,
        status: 'processing',
        images: ['img_a', 'img_b', 'img_c'],
        analysisResults: {
          'diseases': ['disease_1', 'disease_2'],
          'confidence_scores': [0.85, 0.92],
          'metadata': {'version': '1.0', 'model': 'v2.3'}
        },
      );

      // Act
      final map = originalPlant.toMap();
      final recreatedPlant = PlantModel.fromMap(map);

      // Assert
      expect(recreatedPlant.plantId, originalPlant.plantId);
      expect(recreatedPlant.userId, originalPlant.userId);
      expect(recreatedPlant.createdAt, originalPlant.createdAt);
      expect(recreatedPlant.status, originalPlant.status);
      expect(recreatedPlant.images, originalPlant.images);
      expect(recreatedPlant.analysisResults, originalPlant.analysisResults);
    });
  });
}