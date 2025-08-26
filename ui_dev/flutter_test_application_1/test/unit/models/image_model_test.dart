import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_application_1/models/image_model.dart';

void main() {
  group('ImageModel', () {
    final testDateTime = DateTime(2025, 8, 20, 15, 45, 30);
    final testTimestamp = Timestamp.fromDate(testDateTime);

    test('should create instance with all required fields', () {
      // Arrange & Act
      final image = ImageModel(
        imageId: 'img_001',
        plantId: 'plant_123',
        userId: 'user_456',
        originalUrl: 'https://storage.example.com/original/img_001.jpg',
        processedUrls: {
          'thumbnail': 'https://storage.example.com/thumb/img_001.jpg',
          'analyzed': 'https://storage.example.com/analyzed/img_001.jpg',
        },
        uploadTime: testDateTime,
        metadata: {
          'fileSize': 2048576,
          'resolution': '1920x1080',
          'camera': 'iPhone 13 Pro'
        },
      );

      // Assert
      expect(image.imageId, 'img_001');
      expect(image.plantId, 'plant_123');
      expect(image.userId, 'user_456');
      expect(image.originalUrl, 'https://storage.example.com/original/img_001.jpg');
      expect(image.processedUrls['thumbnail'], 'https://storage.example.com/thumb/img_001.jpg');
      expect(image.processedUrls['analyzed'], 'https://storage.example.com/analyzed/img_001.jpg');
      expect(image.uploadTime, testDateTime);
      expect(image.metadata?['fileSize'], 2048576);
    });

    test('should create instance with null metadata', () {
      // Arrange & Act
      final image = ImageModel(
        imageId: 'img_002',
        plantId: 'plant_456',
        userId: 'user_789',
        originalUrl: 'https://storage.example.com/original/img_002.jpg',
        processedUrls: {'thumbnail': 'https://storage.example.com/thumb/img_002.jpg'},
        uploadTime: testDateTime,
      );

      // Assert
      expect(image.metadata, isNull);
    });

    test('should convert to map correctly', () {
      // Arrange
      final image = ImageModel(
        imageId: 'img_003',
        plantId: 'plant_789',
        userId: 'user_101',
        originalUrl: 'https://storage.example.com/original/img_003.png',
        processedUrls: {
          'thumbnail': 'https://storage.example.com/thumb/img_003.png',
          'segmented': 'https://storage.example.com/segment/img_003.png',
        },
        uploadTime: testDateTime,
        metadata: {'format': 'PNG', 'quality': 'high'},
      );

      // Act
      final map = image.toMap();

      // Assert
      expect(map['imageId'], 'img_003');
      expect(map['plantId'], 'plant_789');
      expect(map['userId'], 'user_101');
      expect(map['originalUrl'], 'https://storage.example.com/original/img_003.png');
      expect(map['processedUrls'], isA<Map<String, String>>());
      expect(map['processedUrls']['thumbnail'], 'https://storage.example.com/thumb/img_003.png');
      expect(map['processedUrls']['segmented'], 'https://storage.example.com/segment/img_003.png');
      expect(map['uploadTime'], isA<Timestamp>());
      expect((map['uploadTime'] as Timestamp).toDate(), testDateTime);
      expect(map['metadata'], {'format': 'PNG', 'quality': 'high'});
    });

    test('should convert from map correctly', () {
      // Arrange
      final map = {
        'imageId': 'img_004',
        'plantId': 'plant_202',
        'userId': 'user_303',
        'originalUrl': 'https://storage.example.com/original/img_004.jpg',
        'processedUrls': {
          'thumbnail': 'https://storage.example.com/thumb/img_004.jpg',
          'enhanced': 'https://storage.example.com/enhanced/img_004.jpg',
        },
        'uploadTime': testTimestamp,
        'metadata': {
          'location': 'Garden A',
          'weather': 'sunny',
          'temperature': '25°C'
        },
      };

      // Act
      final image = ImageModel.fromMap(map);

      // Assert
      expect(image.imageId, 'img_004');
      expect(image.plantId, 'plant_202');
      expect(image.userId, 'user_303');
      expect(image.originalUrl, 'https://storage.example.com/original/img_004.jpg');
      expect(image.processedUrls['thumbnail'], 'https://storage.example.com/thumb/img_004.jpg');
      expect(image.processedUrls['enhanced'], 'https://storage.example.com/enhanced/img_004.jpg');
      expect(image.uploadTime, testDateTime);
      expect(image.metadata?['location'], 'Garden A');
      expect(image.metadata?['weather'], 'sunny');
    });

    test('should handle null metadata in map conversion', () {
      // Arrange
      final map = {
        'imageId': 'img_005',
        'plantId': 'plant_505',
        'userId': 'user_606',
        'originalUrl': 'https://storage.example.com/original/img_005.jpg',
        'processedUrls': {'thumbnail': 'https://storage.example.com/thumb/img_005.jpg'},
        'uploadTime': testTimestamp,
        'metadata': null,
      };

      // Act
      final image = ImageModel.fromMap(map);

      // Assert
      expect(image.metadata, isNull);
    });

    test('should handle empty processedUrls map', () {
      // Arrange & Act
      final image = ImageModel(
        imageId: 'img_empty',
        plantId: 'plant_empty',
        userId: 'user_empty',
        originalUrl: 'https://storage.example.com/original/img_empty.jpg',
        processedUrls: {},
        uploadTime: testDateTime,
      );

      // Assert
      expect(image.processedUrls, isEmpty);
      expect(image.processedUrls, isA<Map<String, String>>());
    });

    test('should maintain data integrity through map round-trip', () {
      // Arrange
      final originalImage = ImageModel(
        imageId: 'img_roundtrip',
        plantId: 'plant_roundtrip',
        userId: 'user_roundtrip',
        originalUrl: 'https://storage.example.com/original/img_roundtrip.jpg',
        processedUrls: {
          'thumbnail': 'https://storage.example.com/thumb/img_roundtrip.jpg',
          'analyzed': 'https://storage.example.com/analyzed/img_roundtrip.jpg',
          'segmented': 'https://storage.example.com/segment/img_roundtrip.jpg',
        },
        uploadTime: testDateTime,
        metadata: {
          'camera_settings': {
            'iso': 200,
            'aperture': 'f/2.8',
            'shutter_speed': '1/125'
          },
          'analysis_version': '2.1.0',
          'upload_source': 'mobile_app'
        },
      );

      // Act
      final map = originalImage.toMap();
      final recreatedImage = ImageModel.fromMap(map);

      // Assert
      expect(recreatedImage.imageId, originalImage.imageId);
      expect(recreatedImage.plantId, originalImage.plantId);
      expect(recreatedImage.userId, originalImage.userId);
      expect(recreatedImage.originalUrl, originalImage.originalUrl);
      expect(recreatedImage.processedUrls, originalImage.processedUrls);
      expect(recreatedImage.uploadTime, originalImage.uploadTime);
      expect(recreatedImage.metadata, originalImage.metadata);
    });

    test('should handle URLs with special characters', () {
      // Arrange
      final image = ImageModel(
        imageId: 'img_special',
        plantId: 'plant_special',
        userId: 'user_special',
        originalUrl: 'https://storage.example.com/original/img%20with%20spaces.jpg?token=abc123',
        processedUrls: {
          'thumbnail': 'https://storage.example.com/thumb/img%20with%20spaces.jpg?size=small',
        },
        uploadTime: testDateTime,
      );

      // Act
      final map = image.toMap();
      final recreatedImage = ImageModel.fromMap(map);

      // Assert
      expect(recreatedImage.originalUrl, image.originalUrl);
      expect(recreatedImage.processedUrls['thumbnail'], image.processedUrls['thumbnail']);
    });
  });
}