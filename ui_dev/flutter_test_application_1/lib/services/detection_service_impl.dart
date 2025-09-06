import 'detection_service.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test_application_1/utils/logger.dart';
import 'package:flutter_test_application_1/services/tflite_interop/tflite_wrapper.dart';

/// Implementation of the DetectionService using TFLite
class DetectionServiceImpl implements DetectionService {
  // Singleton Pattern
  static final DetectionServiceImpl _instance =
      DetectionServiceImpl._internal();
  factory DetectionServiceImpl() => _instance;
  DetectionServiceImpl._internal();

  static const String _tfliteModelPath =
      'assets/models/plant_disease_model.tflite';
  static const String _tfliteLabelsPath = 'assets/models/labels_village.txt';

  TfliteInterpreter? _interpreter;
  List<String>? _labels;
  bool _isLoadingModel = false;

  @override
  bool get isModelLoaded => _interpreter?.isModelLoaded ?? false;

  @override
  Future<void> loadModel() async {
    if (isModelLoaded) {
      if (kDebugMode) {
        logger.i('[DetectionService] Model already loaded.');
      }
      return;
    }
    if (_isLoadingModel) {
      if (kDebugMode) {
        logger.i('[DetectionService] Model loading already in progress.');
      }
      return;
    }

    _isLoadingModel = true;
    if (kDebugMode) {
      logger.i('[DetectionService] Starting to load model...');
    }

    try {
      _interpreter = TfliteInterpreter();
      final options = TfliteOptions()..threads = 2;
      await _interpreter!.loadModel(_tfliteModelPath, options: options);

      final rawLabels = await rootBundle.loadString(_tfliteLabelsPath);
      _labels =
          rawLabels
              .split(RegExp(r'\r?\n'))
              .where((e) => e.trim().isNotEmpty)
              .toList();

      if (kDebugMode && isModelLoaded) {
        logger.i(
          '[DetectionService] TFLite Model and Labels loaded successfully.',
        );
      } else if (kDebugMode) {
        logger.w('[DetectionService] TFLite Model FAILED to load.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        logger.e('[DetectionService] Error loading model: $e\n$stackTrace');
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
    if (!isModelLoaded) await loadModel();
    if (!isModelLoaded || _interpreter == null || _labels == null) {
      throw Exception("TFLite model/interpreter/labels not loaded.");
    }

    final img.Image? decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) throw Exception('Failed to decode image.');

    final inputTensor = _interpreter!.getInputTensor(0);
    final inputShape = inputTensor.shape; // expect [1,H,W,3]
    final inputHeight = inputShape[1];
    final inputWidth = inputShape[2];

    final img.Image resizedImage = img.copyResize(
      decodedImage,
      width: inputWidth,
      height: inputHeight,
    );

    // Build nested 4D input [1, H, W, 3] in [0,1]
    final inputNested = [
      List.generate(inputHeight, (y) {
        return List.generate(inputWidth, (x) {
          final p = resizedImage.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        });
      }),
    ];

    // Prepare output buffer as nested list matching [1, numClasses]
    final outputTensor = _interpreter!.getOutputTensor(0);
    final outShape = outputTensor.shape; // e.g., [1, N]
    final batch = outShape[0];
    final numClasses = outShape.length > 1 ? outShape[1] : 1;
    final outputNested = List.generate(
      batch,
      (_) => List.filled(numClasses, 0.0),
    );

    // Run inference
    _interpreter!.run(inputNested, outputNested);

    // Extract probabilities from [1, N]
    final List<double> probabilities =
        (outputNested[0] as List<dynamic>).cast<double>();
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
    return [];
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
    if (kDebugMode) logger.i('[DetectionService] Disposed.');
  }

  // Progress Tracking Implementation
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
