import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:async';

class DetectionService {
  // --- Singleton Pattern Start ---
  static final DetectionService _instance = DetectionService._internal();

  factory DetectionService() {
    return _instance;
  }

  DetectionService._internal();
  // --- Singleton Pattern End ---

  static const String _modelPath = 'assets/models/plant_disease_model.tflite';
  static const String _labelsPath = 'assets/models/labels_village.txt';
  // Remove unused model params if input size comes from tensor
  // static const int _inputSize = 224;
  // static const double _mean = 127.5;
  // static const double _std = 127.5;

  Interpreter? _interpreter;
  List<String>? _labels;
  bool _modelLoaded = false;
  bool _isLoadingModel = false;

  // Remove progress stream map and related methods
  // final Map<String, StreamController<AnalysisProgress>> _progressControllers =
  //     {};
  // Stream<AnalysisProgress>? getProgressStream(String plantId) {
  //   return _progressControllers[plantId]?.stream;
  // }

  // Getter to check if model is loaded
  bool get isModelLoaded => _modelLoaded;

  Future<void> loadModel() async {
    if (_modelLoaded) {
      if (kDebugMode) print('[DetectionService] Model already loaded.');
      return;
    }
    if (_isLoadingModel) {
      if (kDebugMode)
        print('[DetectionService] Model loading already in progress.');
      return; // Avoid concurrent loading
    }

    _isLoadingModel = true;
    if (kDebugMode) print('[DetectionService] Starting to load model...');

    try {
      final options = InterpreterOptions()..threads = 2;
      // Consider adding delegates here if needed (e.g., options.addDelegate(GpuDelegateV2()); )
      if (kDebugMode) print('[DetectionService] Interpreter options set.');
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      if (kDebugMode)
        print('[DetectionService] Interpreter loaded from asset.');

      final rawLabels = await rootBundle.loadString(_labelsPath);
      _labels = rawLabels.split('\\n').where((e) => e.isNotEmpty).toList();
      if (kDebugMode) print('[DetectionService] Labels loaded from asset.');

      _modelLoaded = true;
      if (kDebugMode) {
        print(
          '[DetectionService] Model loaded successfully. Input: ${_interpreter!.getInputTensor(0).shape}',
        );
        print(
          '[DetectionService] Output: ${_interpreter!.getOutputTensor(0).shape}',
        );
        print('[DetectionService] Labels loaded: ${_labels?.length}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode)
        print(
          '[DetectionService] Error loading TFLite model or labels: $e\\n$stackTrace',
        );
      _modelLoaded = false;
      // Don't rethrow here, handle it in detect maybe? Or return a status?
      // For now, just log the error.
    } finally {
      _isLoadingModel = false; // Reset the flag regardless of success/failure
      if (kDebugMode)
        print('[DetectionService] Finished loading model attempt.');
    }
  }

  Future<List<DetectionResult>> detect(
    File imageFile,
    String plantId, // Keep plantId for logging
  ) async {
    if (kDebugMode)
      print(
        '[DetectionService] detect called for ${imageFile.path} (Plant: $plantId)',
      ); // Add plantId to log
    if (!_modelLoaded || _interpreter == null || _labels == null) {
      if (kDebugMode)
        print('[DetectionService] Model not loaded, attempting to load...');
      await loadModel();
      if (!_modelLoaded || _interpreter == null || _labels == null) {
        if (kDebugMode)
          print(
            '[DetectionService] Model or labels failed to load after attempt.',
          );
        throw Exception('Model or labels failed to load.');
      }
      if (kDebugMode)
        print('[DetectionService] Model successfully loaded/verified.');
    }

    // Remove progress stream handling
    // final progressController = StreamController<AnalysisProgress>.broadcast();
    // _progressControllers[plantId] = progressController;

    try {
      // 1. Preprocessing
      // Remove progressController.add calls
      if (kDebugMode)
        print('[DetectionService] Preprocessing image for $plantId...');

      // Decode image
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];
      final resizedImage = img.copyResize(
        decodedImage,
        width: inputWidth,
        height: inputHeight,
      );
      var inputBytes = resizedImage.getBytes(order: img.ChannelOrder.rgb);
      var inputAsList = inputBytes.map((byte) => byte / 255.0).toList();
      var inputBuffer = Float32List(1 * inputHeight * inputWidth * 3);
      int bufferIndex = 0;
      for (int i = 0; i < inputAsList.length; i++) {
        inputBuffer[bufferIndex++] = inputAsList[i];
      }
      var reshapedInput = inputBuffer.reshape([1, inputHeight, inputWidth, 3]);

      // 2. Detection
      if (kDebugMode)
        print('[DetectionService] Running model inference for $plantId...');
      // Remove progressController.add calls

      // Prepare output buffer
      final outputTensor = _interpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      final outputBuffer =
          List.filled(outputShape[0] * outputShape[1], 0.0).reshape(outputShape)
              as List<List<double>>;
      _interpreter!.run(reshapedInput, outputBuffer);

      // Remove simulated delay and progress update
      // await Future.delayed(Duration(milliseconds: 500));
      // progressController.add(...);

      // 3. Postprocessing
      if (kDebugMode)
        print('[DetectionService] Postprocessing results for $plantId...');
      // Remove progressController.add calls

      // Assuming outputBuffer[0] contains the list of confidences for each class
      final results = outputBuffer[0];
      final List<DetectionResult> detectionResults = [];

      // Find top results (e.g., confidence > threshold)
      double threshold = 0.1; // Example threshold
      for (int i = 0; i < results.length; i++) {
        if (results[i] > threshold && i < _labels!.length) {
          detectionResults.add(
            DetectionResult(diseaseName: _labels![i], confidence: results[i]),
          );
        }
      }

      // Sort results by confidence
      detectionResults.sort((a, b) => b.confidence.compareTo(a.confidence));

      // 4. Complete
      // Remove progressController.add call
      // Remove delay and stream closing logic
      if (kDebugMode)
        print('[DetectionService] Detection successful for $plantId.');

      return detectionResults;
    } catch (e, stackTrace) {
      print(
        '[DetectionService] Error during detection for plant $plantId: $e\n$stackTrace',
      );
      // Remove progress controller handling/emission
      rethrow; // Re-throw the exception so PlantService knows it failed
    }
  }

  void dispose() {
    _interpreter?.close();
    _modelLoaded = false;
    if (kDebugMode) print('[DetectionService] TFLite interpreter disposed.');
    // Remove progress controller clearing
    // _progressControllers.values.forEach((controller) => controller.close());
    // _progressControllers.clear();
    // if (kDebugMode) print('[DetectionService] Cleared progress controllers.');
  }
}
