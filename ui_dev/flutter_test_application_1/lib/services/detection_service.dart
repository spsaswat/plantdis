// lib/services/detection_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';

// This is a special syntax for conditional imports.
// It tries to import 'detection_service_mobile.dart' by default.
// If 'dart.library.html' is available (meaning, we are on the web),
// it imports 'detection_service_web.dart' instead.
import 'detection_service_mobile.dart'
if (dart.library.html) 'detection_service_web.dart';

/// Abstract base class for the Detection Service.
/// Defines the contract that all platform-specific implementations must follow.
abstract class DetectionService {
  // --- Singleton Pattern ---
  static DetectionService? _instance;

  /// The factory constructor now handles the lazy initialization.
  factory DetectionService() {
    // only when _instance is null, call _getDetectionService()
    _instance ??= getDetectionService();
    return _instance!;
  }
  // --- Singleton Pattern End ---

  /// A getter to check if the underlying model is loaded.
  bool get isModelLoaded;

  /// Loads the appropriate ML model for the current platform.
  Future<void> loadModel();

  /// Runs inference on the provided image bytes.
  Future<List<DetectionResult>> detect({
    required Uint8List imageBytes,
    required String plantId,
  });

  /// Disposes of any resources used by the service (e.g., TFLite interpreter).
  void dispose();

  /// Returns a stream of analysis progress for the given plant ID.
  Stream<AnalysisProgress>? getProgressStream(String plantId);

  /// Starts tracking analysis progress for a plant and returns its stream.
  Stream<AnalysisProgress> startProgressTracking(String plantId);

  /// Updates the analysis progress for a specific plant.
  void updateProgress(String plantId, AnalysisProgress progress);
}