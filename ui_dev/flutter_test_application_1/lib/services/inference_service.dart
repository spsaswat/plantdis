import 'dart:async';
import 'dart:io';
import 'dart:math'; // Keep Random if needed for other logic, or remove if not.
import 'package:flutter_test_application_1/models/detection_result.dart';
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:flutter_test_application_1/services/detection_service.dart'; // Use the correct service
// import 'package:flutter_test_application_1/services/segmentation_service.dart';

/// Service to handle ML model inference for plant disease detection.
/// Provides progress feedback via stream during analysis.
class InferenceService {
  // Use the correct TFLite Flutter service
  // final SegmentationService _segmentationService = SegmentationService();
  final DetectionService _detectionService = DetectionService();
  final _random = Random(); // Still used for simulateAnalysis

  /// Stream controller for progress updates.
  final _progressController = StreamController<AnalysisProgress>.broadcast();

  /// Returns stream of progress updates for the UI.
  Stream<AnalysisProgress> get progressStream => _progressController.stream;

  /// Runs actual inference using the TFLite Flutter model
  Future<DetectionResult?> analyzeImage(File imageFile) async {
    try {
      _updateProgress(AnalysisStage.preprocessing, 0.1, "Preparing...");
      await _detectionService.loadModel(); // Ensure model is loaded

      // _updateProgress(AnalysisStage.preprocessing, 0.25, "Segmenting leaf...");
      // await _segmentationService.loadModel();
      // File segFile = await _segmentationService.segment(imageFile);
      // print('Segmentation output at: ${segFile.path}');    

      _updateProgress(AnalysisStage.detecting, 0.4, "Detecting...");
      List<DetectionResult> results = await _detectionService.detect(imageFile);

      _updateProgress(AnalysisStage.postprocessing, 0.9, "Finalizing...");
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Short delay for UI

      if (results.isEmpty) {
        _updateProgress(AnalysisStage.completed, 1.0, "No disease detected.");
        // Return a "Healthy" placeholder or null depending on desired behavior
        return DetectionResult(
          diseaseName: "Healthy / Unknown",
          confidence: 0.0,
        );
      }

      final topResult = results.first;
      _updateProgress(AnalysisStage.completed, 1.0, "Analysis Complete");
      print(
        "TFLite analysis complete. Top: ${topResult.diseaseName} (${topResult.confidence.toStringAsFixed(2)})",
      );
      return topResult;
    } catch (e) {
      print("Error during TFLite analysis: $e");
      _updateProgress(AnalysisStage.failed, 0.0, "Error: ${e.toString()}");
      return null;
    }
  }

  /// Simulates analysis (kept for potential testing/fallback)
  Future<void> simulateAnalysis() async {
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

      _updateProgress(AnalysisStage.completed, 1.0, "Simulation Complete");
    } catch (e) {
      _updateProgress(
        AnalysisStage.failed,
        0.0,
        "Simulation Error: ${e.toString()}",
      );
    }
  }

  /// Helper to emit a progress update.
  void _updateProgress(
    AnalysisStage stage,
    double progress, [
    String? message,
  ]) {
    final String stageMessage =
        message ?? ''; // Use provided message or derive one
    _progressController.add(
      AnalysisProgress(
        stage: stage,
        progress: progress,
        message: stageMessage, // Use the AnalysisProgress model's message field
        errorMessage: stage == AnalysisStage.failed ? stageMessage : null,
      ),
    );
  }

  /// Call to clean up resources when done.
  void dispose() {
    _detectionService.dispose(); // Dispose the TFLite interpreter
    _progressController.close();
  }
}
