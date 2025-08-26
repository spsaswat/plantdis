import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';

void main() {
  group('BoundingBox', () {
    test('should create instance with coordinates', () {
      // Arrange & Act
      final bbox = BoundingBox(
        xMin: 10.5,
        yMin: 20.3,
        xMax: 150.7,
        yMax: 200.9,
      );

      // Assert
      expect(bbox.xMin, 10.5);
      expect(bbox.yMin, 20.3);
      expect(bbox.xMax, 150.7);
      expect(bbox.yMax, 200.9);
    });

    test('should convert to JSON correctly', () {
      // Arrange
      final bbox = BoundingBox(xMin: 0.0, yMin: 5.5, xMax: 100.0, yMax: 80.0);

      // Act
      final json = bbox.toJson();

      // Assert
      expect(json['xMin'], 0.0);
      expect(json['yMin'], 5.5);
      expect(json['xMax'], 100.0);
      expect(json['yMax'], 80.0);
    });

    test('should create from JSON correctly', () {
      // Arrange
      final json = {
        'xMin': 15.5,
        'yMin': 25.3,
        'xMax': 175.8,
        'yMax': 225.1,
      };

      // Act
      final bbox = BoundingBox.fromJson(json);

      // Assert
      expect(bbox.xMin, 15.5);
      expect(bbox.yMin, 25.3);
      expect(bbox.xMax, 175.8);
      expect(bbox.yMax, 225.1);
    });

    test('should handle integer values in JSON', () {
      // Arrange
      final json = {
        'xMin': 10,
        'yMin': 20,
        'xMax': 100,
        'yMax': 200,
      };

      // Act
      final bbox = BoundingBox.fromJson(json);

      // Assert
      expect(bbox.xMin, 10.0);
      expect(bbox.yMin, 20.0);
      expect(bbox.xMax, 100.0);
      expect(bbox.yMax, 200.0);
    });

    test('should maintain precision through JSON round-trip', () {
      // Arrange
      final originalBbox = BoundingBox(
        xMin: 123.456789,
        yMin: 987.654321,
        xMax: 500.123456,
        yMax: 600.987654,
      );

      // Act
      final json = originalBbox.toJson();
      final recreatedBbox = BoundingBox.fromJson(json);

      // Assert
      expect(recreatedBbox.xMin, originalBbox.xMin);
      expect(recreatedBbox.yMin, originalBbox.yMin);
      expect(recreatedBbox.xMax, originalBbox.xMax);
      expect(recreatedBbox.yMax, originalBbox.yMax);
    });
  });

  group('DetectionResult', () {
    final testDateTime = DateTime(2025, 8, 20, 14, 30, 45);
    final testTimestamp = Timestamp.fromDate(testDateTime);

    test('should create instance with all fields', () {
      // Arrange
      final bbox = BoundingBox(xMin: 10, yMin: 20, xMax: 100, yMax: 200);

      // Act
      final result = DetectionResult(
        diseaseName: 'leaf_spot',
        confidence: 0.85,
        boundingBox: bbox,
        id: 'detection_001',
        timestamp: testDateTime,
      );

      // Assert
      expect(result.diseaseName, 'leaf_spot');
      expect(result.confidence, 0.85);
      expect(result.boundingBox, bbox);
      expect(result.id, 'detection_001');
      expect(result.timestamp, testDateTime);
    });

    test('should create instance with minimal required fields', () {
      // Arrange & Act
      const result = DetectionResult(
        diseaseName: 'healthy',
        confidence: 0.95,
      );

      // Assert
      expect(result.diseaseName, 'healthy');
      expect(result.confidence, 0.95);
      expect(result.boundingBox, isNull);
      expect(result.id, isNull);
      expect(result.timestamp, isNull);
    });

    test('should create from Firestore data correctly', () {
      // Arrange
      final firestoreData = {
        'disease_name': 'bacterial_blight',
        'confidence': 0.78,
        'bounding_box': {
          'xMin': 50.0,
          'yMin': 75.0,
          'xMax': 200.0,
          'yMax': 300.0,
        },
        'timestamp': testTimestamp,
      };

      // Act
      final result = DetectionResult.fromFirestore(firestoreData, 'doc_123');

      // Assert
      expect(result.id, 'doc_123');
      expect(result.diseaseName, 'bacterial_blight');
      expect(result.confidence, 0.78);
      expect(result.boundingBox, isNotNull);
      expect(result.boundingBox!.xMin, 50.0);
      expect(result.boundingBox!.yMin, 75.0);
      expect(result.boundingBox!.xMax, 200.0);
      expect(result.boundingBox!.yMax, 300.0);
      expect(result.timestamp, testDateTime);
    });

    test('should handle null bounding box in Firestore data', () {
      // Arrange
      final firestoreData = {
        'disease_name': 'powdery_mildew',
        'confidence': 0.65,
        'bounding_box': null,
        'timestamp': testTimestamp,
      };

      // Act
      final result = DetectionResult.fromFirestore(firestoreData, 'doc_456');

      // Assert
      expect(result.boundingBox, isNull);
      expect(result.diseaseName, 'powdery_mildew');
      expect(result.confidence, 0.65);
    });

    test('should handle null timestamp in Firestore data', () {
      // Arrange
      final firestoreData = {
        'disease_name': 'rust',
        'confidence': 0.90,
        'bounding_box': null,
        'timestamp': null,
      };

      // Act
      final result = DetectionResult.fromFirestore(firestoreData, 'doc_789');

      // Assert
      expect(result.timestamp, isNull);
      expect(result.diseaseName, 'rust');
      expect(result.confidence, 0.90);
    });

    test('should convert to map correctly', () {
      // Arrange
      final bbox = BoundingBox(xMin: 25, yMin: 50, xMax: 150, yMax: 250);
      final result = DetectionResult(
        diseaseName: 'anthracnose',
        confidence: 0.82,
        boundingBox: bbox,
        id: 'detection_002',
        timestamp: testDateTime,
      );

      // Act
      final map = result.toMap();

      // Assert
      expect(map['diseaseName'], 'anthracnose');
      expect(map['confidence'], 0.82);
      expect(map['boundingBox'], isA<Map<String, double>>());
      expect(map['boundingBox']['xMin'], 25.0);
      expect(map['boundingBox']['yMin'], 50.0);
      expect(map['boundingBox']['xMax'], 150.0);
      expect(map['boundingBox']['yMax'], 250.0);
      expect(map['timestamp'], isA<Timestamp>());
      expect((map['timestamp'] as Timestamp).toDate(), testDateTime);
      expect(map.containsKey('id'), false); // ID should not be in map
    });

    test('should handle null boundingBox in toMap', () {
      // Arrange
      const result = DetectionResult(
        diseaseName: 'no_disease',
        confidence: 0.99,
      );

      // Act
      final map = result.toMap();

      // Assert
      expect(map['boundingBox'], isNull);
      expect(map['timestamp'], isNull);
    });

    test('should handle integer confidence values', () {
      // Arrange
      final firestoreData = {
        'disease_name': 'leaf_curl',
        'confidence': 1, // integer instead of double
        'bounding_box': null,
        'timestamp': null,
      };

      // Act
      final result = DetectionResult.fromFirestore(firestoreData, 'doc_int');

      // Assert
      expect(result.confidence, 1.0);
      expect(result.confidence, isA<double>());
    });

    test('should handle edge case confidence values', () {
      // Test minimum confidence
      const minResult = DetectionResult(
        diseaseName: 'uncertain',
        confidence: 0.0,
      );
      expect(minResult.confidence, 0.0);

      // Test maximum confidence
      const maxResult = DetectionResult(
        diseaseName: 'certain',
        confidence: 1.0,
      );
      expect(maxResult.confidence, 1.0);
    });

    test('should handle special disease names', () {
      const result1 = DetectionResult(
        diseaseName: 'No disease detected',
        confidence: 0.95,
      );
      expect(result1.diseaseName, 'No disease detected');

      const result2 = DetectionResult(
        diseaseName: 'multiple_diseases_detected',
        confidence: 0.75,
      );
      expect(result2.diseaseName, 'multiple_diseases_detected');
    });

    test('should preserve const constructor behavior', () {
      // This test ensures the const constructor works correctly
      const result1 = DetectionResult(
        diseaseName: 'test_disease',
        confidence: 0.5,
      );
      
      const result2 = DetectionResult(
        diseaseName: 'test_disease',
        confidence: 0.5,
      );

      // These should be the same instance due to const constructor
      expect(identical(result1, result2), true);
    });
  });
}
