// lib/services/detection_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';

import 'detection_service_impl.dart';

/// Abstract base class for the Detection Service.
/// Defines the contract that all implementations must follow.
abstract class DetectionService {
  // --- Singleton Pattern ---
  static DetectionService? _instance;

  /// The factory constructor handles the lazy initialization.
  factory DetectionService() {
    _instance ??= DetectionServiceImpl();
    return _instance!;
  }
  // --- Singleton Pattern End ---

  /// A getter to check if the underlying model is loaded.
  bool get isModelLoaded;

  /// Loads the ML model.
  Future<void> loadModel();

  /// Runs inference on the provided image bytes.
  Future<List<DetectionResult>> detect({
    required Uint8List imageBytes,
    required String plantId,
  });

  /// Disposes of any resources used by the service.
  void dispose();

  /// Returns a stream of analysis progress for the given plant ID.
  Stream<AnalysisProgress>? getProgressStream(String plantId);

  /// Starts tracking analysis progress for a plant and returns its stream.
  Stream<AnalysisProgress> startProgressTracking(String plantId);

  /// Updates the analysis progress for a specific plant.
  void updateProgress(String plantId, AnalysisProgress progress);
}
