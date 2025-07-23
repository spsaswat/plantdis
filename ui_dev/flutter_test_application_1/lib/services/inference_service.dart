// lib/services/inference_service.dart

import 'dart:async';
import 'dart:typed_data'; // Added for Uint8List
import 'dart:math'; // Keep Random if needed for other logic, or remove if not.

import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:flutter_test_application_1/models/detection_result.dart';
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:flutter_test_application_1/services/detection_service.dart'; // Use the correct service

/// Service to handle ML model inference for plant disease detection.
/// Provides progress feedback via stream during analysis.
class InferenceService {
  final DetectionService _detectionService = DetectionService();

  /// Stream controller for progress updates.
  final _progressController = StreamController<AnalysisProgress>.broadcast();

  /// Returns stream of progress updates for the UI.
  Stream<AnalysisProgress> get progressStream => _progressController.stream;

  /// Runs actual inference using the model.
  /// Takes imageBytes, a plantId for context, and segmentation status.
  Future<DetectionResult?> analyzeImage({
    required Uint8List imageBytes,
    required String plantId,
    required bool isSegmented, // <<< --- 这里是关键修改 (THIS IS THE KEY CHANGE)
  }) async {
    try {
      if (kDebugMode) {
        print(
          '[InferenceService] Starting analysis. Plant ID: $plantId, Is Segmented: $isSegmented',
        );
      }
      _updateProgress(AnalysisStage.preprocessing, 0.1, "Preparing model...");
      // DetectionService.loadModel() is called within DetectionService.detect() if not loaded.

      _updateProgress(AnalysisStage.detecting, 0.4, "Analyzing image...");
      // The call to detection service itself doesn't need the isSegmented flag,
      // as it just processes the bytes it's given.
      List<DetectionResult> results = await _detectionService.detect(
        imageBytes: imageBytes,
        plantId: plantId,
      );

      _updateProgress(
        AnalysisStage.postprocessing,
        0.9,
        "Finalizing results...",
      );
      await Future.delayed(
        const Duration(milliseconds: 100), // Short delay for UI feedback
      );

      if (results.isEmpty) {
        _updateProgress(
          AnalysisStage.completed,
          1.0,
          "No significant findings.",
        );
        // Return a placeholder or specific result for "not detected"
        return DetectionResult(
          diseaseName: "Healthy / Not Detected",
          confidence: 0.0,
          boundingBox: null,
        );
      }

      // Assuming the first result is the most relevant one
      final topResult = results.first;
      _updateProgress(AnalysisStage.completed, 1.0, "Analysis Complete");
      if (kDebugMode) {
        print(
          "[InferenceService] Analysis complete. Top result: ${topResult.diseaseName} (${topResult.confidence.toStringAsFixed(2)}) for plant $plantId",
        );
      }
      return topResult;
    } catch (e) {
      if (kDebugMode) {
        print(
          "[InferenceService] Error during analysis for plant $plantId: $e",
        );
      }
      _updateProgress(
        AnalysisStage.failed,
        0.0,
        "Error during analysis: ${e.toString()}",
      );
      return null; // Indicate failure
    }
  }

  /// Simulates analysis (kept for potential testing/fallback)
  /// This method would also need to be updated if it relies on File type directly.
  Future<void> simulateAnalysis({String plantId = "simulated_plant"}) async {
    final _random = Random(); // Make it local if only used here
    try {
      _updateProgress(
        AnalysisStage.preprocessing,
        0.0,
        "Simulating Preprocessing...",
      );
      await Future.delayed(const Duration(milliseconds: 500));
      _updateProgress(AnalysisStage.preprocessing, 0.2);
      await Future.delayed(const Duration(milliseconds: 500));

      _updateProgress(AnalysisStage.detecting, 0.2, "Simulating Detection...");
      await Future.delayed(const Duration(milliseconds: 700));
      _updateProgress(AnalysisStage.detecting, 0.6);
      await Future.delayed(const Duration(milliseconds: 700));

      _updateProgress(
        AnalysisStage.postprocessing,
        0.8,
        "Simulating Postprocessing...",
      );
      await Future.delayed(const Duration(milliseconds: 500));
      _updateProgress(AnalysisStage.postprocessing, 1.0);
      await Future.delayed(const Duration(milliseconds: 500));

      _updateProgress(
        AnalysisStage.completed,
        1.0,
        "Simulation Complete for $plantId",
      );
    } catch (e) {
      _updateProgress(
        AnalysisStage.failed,
        0.0,
        "Simulation Error for $plantId: ${e.toString()}",
      );
    }
  }

  /// Helper to emit a progress update.
  void _updateProgress(
      AnalysisStage stage,
      double progress, [
        String? message,
      ]) {
    final String stageMessage = message ?? '';
    _progressController.add(
      AnalysisProgress(
        stage: stage,
        progress: progress,
        message: stageMessage,
        errorMessage: stage == AnalysisStage.failed ? stageMessage : null,
      ),
    );
  }

  /// Call to clean up resources when done.
  void dispose() {
    _detectionService.dispose();
    _progressController.close();
    if (kDebugMode) {
      print("[InferenceService] Disposed.");
    }
  }
}