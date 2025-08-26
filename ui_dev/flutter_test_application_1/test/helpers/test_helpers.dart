import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:flutter_test_application_1/models/image_model.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';
import 'package:flutter_test_application_1/models/analysis_progress.dart';

/// Test helper utilities for creating test data and common test operations
class TestHelpers {
  // ===================
  // Model Factories
  // ===================

  /// Creates a test PlantModel with default or custom values
  static PlantModel createTestPlant({
    String? plantId,
    String? userId,
    DateTime? createdAt,
    String? status,
    List<String>? images,
    Map<String, dynamic>? analysisResults,
  }) {
    return PlantModel(
      plantId: plantId ?? 'test_plant_001',
      userId: userId ?? 'test_user_123',
      createdAt: createdAt ?? DateTime(2025, 8, 20, 10, 0, 0),
      status: status ?? 'analyzing',
      images: images ?? ['test_img_001', 'test_img_002'],
      analysisResults: analysisResults,
    );
  }

  /// Creates a test ImageModel with default or custom values
  static ImageModel createTestImage({
    String? imageId,
    String? plantId,
    String? userId,
    String? originalUrl,
    Map<String, String>? processedUrls,
    DateTime? uploadTime,
    Map<String, dynamic>? metadata,
  }) {
    return ImageModel(
      imageId: imageId ?? 'test_img_001',
      plantId: plantId ?? 'test_plant_001',
      userId: userId ?? 'test_user_123',
      originalUrl: originalUrl ?? 'https://test.com/original/test_img_001.jpg',
      processedUrls: processedUrls ?? {
        'thumbnail': 'https://test.com/thumb/test_img_001.jpg',
        'analyzed': 'https://test.com/analyzed/test_img_001.jpg',
      },
      uploadTime: uploadTime ?? DateTime(2025, 8, 20, 14, 30, 0),
      metadata: metadata,
    );
  }

  /// Creates a test BoundingBox with default or custom values
  static BoundingBox createTestBoundingBox({
    double? xMin,
    double? yMin,
    double? xMax,
    double? yMax,
  }) {
    return BoundingBox(
      xMin: xMin ?? 10.0,
      yMin: yMin ?? 20.0,
      xMax: xMax ?? 100.0,
      yMax: yMax ?? 200.0,
    );
  }

  /// Creates a test DetectionResult with default or custom values
  static DetectionResult createTestDetectionResult({
    String? diseaseName,
    double? confidence,
    BoundingBox? boundingBox,
    String? id,
    DateTime? timestamp,
  }) {
    return DetectionResult(
      diseaseName: diseaseName ?? 'test_disease',
      confidence: confidence ?? 0.85,
      boundingBox: boundingBox,
      id: id,
      timestamp: timestamp,
    );
  }

  /// Creates a test AnalysisProgress with default or custom values
  static AnalysisProgress createTestAnalysisProgress({
    AnalysisStage? stage,
    double? progress,
    String? message,
    String? errorMessage,
  }) {
    return AnalysisProgress(
      stage: stage ?? AnalysisStage.detecting,
      progress: progress ?? 0.5,
      message: message ?? 'Processing image...',
      errorMessage: errorMessage,
    );
  }

  // ===================
  // Widget Test Helpers
  // ===================

  /// Creates a basic MaterialApp wrapper for widget testing
  static Widget createTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  /// Creates a MaterialApp with custom theme for testing
  static Widget createTestAppWithTheme(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: Scaffold(body: child),
    );
  }

  /// Creates a basic Scaffold wrapper for testing individual widgets
  static Widget wrapInScaffold(Widget child) {
    return Scaffold(body: child);
  }

  // ===================
  // Async Test Helpers
  // ===================

  /// Waits for a specific condition to be true within a timeout
  static Future<void> waitForCondition(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
    Duration checkInterval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (!condition() && stopwatch.elapsed < timeout) {
      await tester.pump(checkInterval);
    }
    
    if (!condition()) {
      throw TimeoutException(
        'Condition not met within ${timeout.inSeconds} seconds'
      );
    }
  }

  /// Waits for a widget to appear on screen
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await waitForCondition(
      tester,
      () => tester.any(finder),
      timeout: timeout,
    );
  }

  /// Waits for a widget to disappear from screen
  static Future<void> waitForWidgetToDisappear(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await waitForCondition(
      tester,
      () => !tester.any(finder),
      timeout: timeout,
    );
  }

  /// Simulates network delay for testing async operations
  static Future<void> simulateNetworkDelay({
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    await Future.delayed(delay);
  }

  /// Simulates slow network for testing loading states
  static Future<void> simulateSlowNetwork({
    Duration delay = const Duration(seconds: 2),
  }) async {
    await Future.delayed(delay);
  }

  // ===================
  // Mock Data Generators
  // ===================

  /// Generates realistic plant analysis results
  static Map<String, dynamic> createMockAnalysisResults({
    String? primaryDisease,
    double? confidence,
    List<String>? secondaryDiseases,
  }) {
    return {
      'primary_disease': primaryDisease ?? 'leaf_spot',
      'confidence': confidence ?? 0.85,
      'secondary_diseases': secondaryDiseases ?? ['bacterial_blight'],
      'health_score': 0.7,
      'recommendations': [
        'Remove affected leaves',
        'Apply fungicide treatment',
        'Improve air circulation'
      ],
      'analysis_timestamp': DateTime.now().toIso8601String(),
      'model_version': '2.1.0',
    };
  }

  /// Generates realistic image metadata
  static Map<String, dynamic> createMockImageMetadata({
    int? fileSize,
    String? resolution,
    String? cameraModel,
  }) {
    return {
      'file_size': fileSize ?? 2048576, // 2MB
      'resolution': resolution ?? '1920x1080',
      'camera_model': cameraModel ?? 'iPhone 13 Pro',
      'capture_time': DateTime.now().toIso8601String(),
      'gps_location': {
        'latitude': -35.2809,
        'longitude': 149.1300, // Canberra coordinates
      },
      'lighting_conditions': 'natural',
      'image_quality': 'high',
    };
  }

  /// Creates a list of test plants with varying statuses
  static List<PlantModel> createTestPlantList(int count) {
    final statuses = ['pending', 'analyzing', 'completed', 'failed'];
    return List.generate(count, (index) {
      return createTestPlant(
        plantId: 'test_plant_${index.toString().padLeft(3, '0')}',
        userId: 'test_user_${(index % 5) + 1}', // 5 different users
        status: statuses[index % statuses.length],
        createdAt: DateTime.now().subtract(Duration(days: index)),
        images: List.generate(
          (index % 3) + 1, // 1-3 images per plant
          (imgIndex) => 'test_img_${index}_${imgIndex}',
        ),
      );
    });
  }

  /// Creates a list of test detection results with varying diseases
  static List<DetectionResult> createTestDetectionList(int count) {
    final diseases = [
      'leaf_spot',
      'bacterial_blight',
      'powdery_mildew',
      'rust',
      'anthracnose',
      'healthy'
    ];

    return List.generate(count, (index) {
      final hasBox = index % 2 == 0; // Every other result has bounding box
      return createTestDetectionResult(
        diseaseName: diseases[index % diseases.length],
        confidence: 0.5 + (index % 5) * 0.1, // Confidence from 0.5 to 0.9
        boundingBox: hasBox ? createTestBoundingBox(
          xMin: (index * 10).toDouble(),
          yMin: (index * 15).toDouble(),
          xMax: (index * 10 + 100).toDouble(),
          yMax: (index * 15 + 150).toDouble(),
        ) : null,
        id: 'detection_${index.toString().padLeft(3, '0')}',
        timestamp: DateTime.now().subtract(Duration(hours: index)),
      );
    });
  }

  // ===================
  // Firestore Mock Helpers
  // ===================

  /// Creates mock Firestore data for PlantModel
  static Map<String, dynamic> createMockFirestorePlantData({
    String? plantId,
    String? userId,
    DateTime? createdAt,
  }) {
    final timestamp = Timestamp.fromDate(createdAt ?? DateTime.now());
    return {
      'plantId': plantId ?? 'test_plant_001',
      'userId': userId ?? 'test_user_123',
      'createdAt': timestamp,
      'status': 'analyzing',
      'images': ['img_001', 'img_002'],
      'analysisResults': createMockAnalysisResults(),
    };
  }

  /// Creates mock Firestore data for ImageModel
  static Map<String, dynamic> createMockFirestoreImageData({
    String? imageId,
    String? plantId,
    DateTime? uploadTime,
  }) {
    final timestamp = Timestamp.fromDate(uploadTime ?? DateTime.now());
    return {
      'imageId': imageId ?? 'test_img_001',
      'plantId': plantId ?? 'test_plant_001',
      'userId': 'test_user_123',
      'originalUrl': 'https://test.com/original/test_img_001.jpg',
      'processedUrls': {
        'thumbnail': 'https://test.com/thumb/test_img_001.jpg',
        'analyzed': 'https://test.com/analyzed/test_img_001.jpg',
      },
      'uploadTime': timestamp,
      'metadata': createMockImageMetadata(),
    };
  }

  /// Creates mock Firestore data for DetectionResult
  static Map<String, dynamic> createMockFirestoreDetectionData({
    String? diseaseName,
    double? confidence,
    bool includeBoundingBox = true,
  }) {
    final data = <String, dynamic>{
      'disease_name': diseaseName ?? 'test_disease',
      'confidence': confidence ?? 0.85,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    };

    if (includeBoundingBox) {
      data['bounding_box'] = {
        'xMin': 10.0,
        'yMin': 20.0,
        'xMax': 100.0,
        'yMax': 200.0,
      };
    }

    return data;
  }

  // ===================
  // Validation Helpers
  // ===================

  /// Validates that a PlantModel has all required fields
  static void validatePlantModel(PlantModel plant) {
    expect(plant.plantId, isNotEmpty);
    expect(plant.userId, isNotEmpty);
    expect(plant.createdAt, isNotNull);
    expect(plant.status, isNotEmpty);
    expect(plant.images, isNotNull);
  }

  /// Validates that an ImageModel has all required fields
  static void validateImageModel(ImageModel image) {
    expect(image.imageId, isNotEmpty);
    expect(image.plantId, isNotEmpty);
    expect(image.userId, isNotEmpty);
    expect(image.originalUrl, isNotEmpty);
    expect(image.processedUrls, isNotNull);
    expect(image.uploadTime, isNotNull);
  }

  /// Validates that a DetectionResult has all required fields
  static void validateDetectionResult(DetectionResult result) {
    expect(result.diseaseName, isNotEmpty);
    expect(result.confidence, greaterThanOrEqualTo(0.0));
    expect(result.confidence, lessThanOrEqualTo(1.0));
  }

  /// Validates that an AnalysisProgress has valid values
  static void validateAnalysisProgress(AnalysisProgress progress) {
    expect(progress.stage, isNotNull);
    expect(progress.progress, greaterThanOrEqualTo(0.0));
    expect(progress.progress, lessThanOrEqualTo(1.0));
    expect(progress.stageLabel, isNotEmpty);
  }

  // ===================
  // Test Data Constants
  // ===================

  /// Common test user IDs
  static const testUserIds = [
    'test_user_001',
    'test_user_002',
    'test_user_003',
  ];

  /// Common test plant IDs
  static const testPlantIds = [
    'test_plant_001',
    'test_plant_002',
    'test_plant_003',
  ];

  /// Common test image URLs
  static const testImageUrls = [
    'https://test.com/image1.jpg',
    'https://test.com/image2.jpg',
    'https://test.com/image3.jpg',
  ];

  /// Common disease names for testing
  static const testDiseaseNames = [
    'leaf_spot',
    'bacterial_blight',
    'powdery_mildew',
    'rust',
    'anthracnose',
    'healthy',
    'No disease detected',
  ];

  /// Common analysis statuses
  static const testAnalysisStatuses = [
    'pending',
    'preprocessing',
    'analyzing',
    'postprocessing',
    'completed',
    'failed',
  ];

  // ===================
  // Matcher Helpers
  // ===================

  /// Custom matcher to check if a DateTime is approximately equal (within seconds)
  static Matcher isApproximately(DateTime expected, {int toleranceSeconds = 1}) {
    return predicate<DateTime>((actual) {
      final difference = actual.difference(expected).abs();
      return difference.inSeconds <= toleranceSeconds;
    }, 'is approximately $expected (±${toleranceSeconds}s)');
  }

  /// Custom matcher to check if a double is within a confidence range
  static Matcher isValidConfidence() {
    return predicate<double>((value) {
      return value >= 0.0 && value <= 1.0;
    }, 'is a valid confidence value between 0.0 and 1.0');
  }

  /// Custom matcher to check if a string is a valid ID format
  static Matcher isValidId(String prefix) {
    return predicate<String>((value) {
      return value.startsWith(prefix) && value.length > prefix.length + 5;
    }, 'is a valid ID with prefix $prefix');
  }

  /// Custom matcher to check if a URL is valid
  static Matcher isValidUrl() {
    return predicate<String>((value) {
      try {
        final uri = Uri.parse(value);
        return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
      } catch (e) {
        return false;
      }
    }, 'is a valid URL');
  }
}

/// Custom exception for test timeouts
class TimeoutException implements Exception {
  final String message;
  const TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}