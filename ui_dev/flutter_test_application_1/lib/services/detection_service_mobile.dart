// lib/services/detection_service_mobile.dart
import 'detection_service.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test_application_1/utils/logger.dart';

// MOBILE-ONLY imports
import 'package:flutter_test_application_1/services/tflite_interop/tflite_wrapper.dart';

/// This function is called by the conditional import in detection_service.dart
/// when the platform is NOT web.
DetectionService getDetectionService() => MobileDetectionService();

/// Mobile-specific implementation of the DetectionService.
class MobileDetectionService implements DetectionService {
  // --- Singleton Pattern Start ---
  static final MobileDetectionService _instance =
      MobileDetectionService._internal();

  factory MobileDetectionService() {
    return _instance;
  }

  MobileDetectionService._internal();
  // --- Singleton Pattern End ---

  static const String _tfliteModelPath =
      'assets/models/plant_disease_model.tflite';
  static const String _tfliteLabelsPath = 'assets/models/labels_village.txt';

  TfliteInterpreterWrapper? _interpreterWrapper;
  List<String>? _labels;
  bool _isLoadingModel = false;

  @override
  bool get isModelLoaded => _interpreterWrapper?.isModelLoaded ?? false;

  @override
  Future<void> loadModel() async {
    // This is the NATIVE-ONLY logic from your original file.
    if (isModelLoaded) {
      if (kDebugMode) {
        logger.i('[DetectionService NATIVE] Model already loaded.');
      }
      return;
    }
    if (_isLoadingModel) {
      if (kDebugMode) {
        logger.i(
          '[DetectionService NATIVE] Model loading already in progress.',
        );
      }
      return;
    }

    _isLoadingModel = true;
    if (kDebugMode) {
      logger.i('[DetectionService NATIVE] Starting to load model...');
    }

    try {
      _interpreterWrapper = TfliteInterpreterWrapper();
      final options = TfliteInterpreterOptions();
      options.threads = 2;
      await _interpreterWrapper!.loadModel(_tfliteModelPath, options: options);

      final rawLabels = await rootBundle.loadString(_tfliteLabelsPath);
      _labels =
          rawLabels
              .split(RegExp(r'\r?\n'))
              .where((e) => e.trim().isNotEmpty)
              .toList();

      if (kDebugMode && isModelLoaded) {
        logger.i(
          '[DetectionService NATIVE] TFLite Model and Labels loaded successfully.',
        );
      } else if (kDebugMode) {
        logger.w('[DetectionService NATIVE] TFLite Model FAILED to load.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        logger.e(
          '[DetectionService NATIVE] Error loading model: $e\n$stackTrace',
        );
      }
      rethrow;
    } finally {
      _isLoadingModel = false;
    }
  }

  @override
  Future<List<DetectionResult>> detect({
    required Uint8List imageBytes,
    required String plantId,
  }) async {
    // This is the NATIVE-ONLY detection logic from your original file.
    if (!isModelLoaded) await loadModel();
    if (!isModelLoaded || _interpreterWrapper == null || _labels == null) {
      throw Exception("TFLite model/interpreter/labels not loaded.");
    }

    final img.Image? decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) throw Exception('Failed to decode image.');

    final inputTensor = _interpreterWrapper!.getInputTensor(0);
    final inputShape = inputTensor.shape;
    //final inputType = inputTensor.type;
    final inputHeight = inputShape[1];
    final inputWidth = inputShape[2];

    final img.Image resizedImage = img.copyResize(
      decodedImage,
      width: inputWidth,
      height: inputHeight,
    );

    // Normalize image and fill input buffer
    final inputBuffer = Float32List(1 * inputHeight * inputWidth * 3);
    int bufferIndex = 0;
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = resizedImage.getPixel(x, y);
        inputBuffer[bufferIndex++] = pixel.r / 255.0;
        inputBuffer[bufferIndex++] = pixel.g / 255.0;
        inputBuffer[bufferIndex++] = pixel.b / 255.0;
      }
    }

    // Prepare output buffer
    final outputTensor = _interpreterWrapper!.getOutputTensor(0);
    final outputBuffer = List.generate(
      outputTensor.shape[0],
      (_) => List.filled(outputTensor.shape[1], 0.0),
    );

    _interpreterWrapper!.run(inputBuffer.buffer, outputBuffer);

    List<double> probabilities =
        (outputBuffer.first as List<dynamic>).cast<double>();
    double maxConfidence = 0.0;
    int maxIndex = -1;
    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxConfidence) {
        maxConfidence = probabilities[i];
        maxIndex = i;
      }
    }

    if (maxIndex != -1) {
      return [
        DetectionResult(
          diseaseName: _labels![maxIndex].replaceAll('_', ' '),
          confidence: maxConfidence,
          boundingBox: null,
        ),
      ];
    }
    return []; // Return empty list if no detection
  }

  @override
  void dispose() {
    _interpreterWrapper?.close();
    _interpreterWrapper = null;
    _labels = null;
    if (kDebugMode) logger.i('[DetectionService NATIVE] Disposed.');
  }

  // --- Progress Tracking Implementation ---
  final Map<String, StreamController<AnalysisProgress>> _progressStreams = {};

  @override
  Stream<AnalysisProgress>? getProgressStream(String plantId) {
    return _progressStreams[plantId]?.stream;
  }

  @override
  Stream<AnalysisProgress> startProgressTracking(String plantId) {
    if (_progressStreams.containsKey(plantId)) {
      return _progressStreams[plantId]!.stream;
    }
    final controller = StreamController<AnalysisProgress>.broadcast();
    _progressStreams[plantId] = controller;
    return controller.stream;
  }

  @override
  void updateProgress(String plantId, AnalysisProgress progress) {
    if (!_progressStreams.containsKey(plantId)) return;
    _progressStreams[plantId]!.add(progress);
    if (progress.stage == AnalysisStage.completed ||
        progress.stage == AnalysisStage.failed) {
      _progressStreams[plantId]!.close();
      _progressStreams.remove(plantId);
    }
  }
}
