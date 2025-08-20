import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test_application_1/services/tflite_interop/tflite_interface.dart';
import 'package:flutter_test_application_1/utils/logger.dart';

/// Service for detecting whether an image contains plant leaves or just background
/// Uses the background_detector_quant.tflite model trained on binary classification
class BackgroundDetectionService {
  // --- Singleton Pattern Start ---
  static final BackgroundDetectionService _instance =
      BackgroundDetectionService._internal();
  factory BackgroundDetectionService() => _instance;
  BackgroundDetectionService._internal();
  // --- Singleton Pattern End ---

  static const String _modelAssetPath =
      'assets/models/background_detector_quant.tflite';

  TfliteInterpreterWrapper? _interpreterWrapper;
  bool _isLoadingModel = false;
  bool _modelLoaded = false;

  /// Check if the background detection model is loaded
  bool get isModelLoaded => _modelLoaded;

  /// Load the background detection TFLite model
  Future<void> loadModel() async {
    if (_modelLoaded) {
      if (kDebugMode) {
        logger.i('[BackgroundDetectionService] Model already loaded.');
      }
      return;
    }
    if (_isLoadingModel) {
      if (kDebugMode) {
        logger.i(
          '[BackgroundDetectionService] Model loading already in progress.',
        );
      }
      return;
    }

    _isLoadingModel = true;
    if (kDebugMode) {
      logger.i(
        '[BackgroundDetectionService] Starting to load background detection model...',
      );
    }

    try {
      // First, verify the model file exists
      final modelData = await rootBundle.load(_modelAssetPath);
      if (kDebugMode) {
        logger.i(
          '[BackgroundDetectionService] Model file loaded, size: ${modelData.lengthInBytes} bytes',
        );
      }

      _interpreterWrapper = TfliteInterpreterWrapper();
      final options = TfliteInterpreterOptions();
      options.threads = 2;

      if (kDebugMode) {
        logger.i(
          '[BackgroundDetectionService] Attempting to load model with path: $_modelAssetPath',
        );
      }

      await _interpreterWrapper!.loadModel(_modelAssetPath, options: options);

      if (kDebugMode && _interpreterWrapper!.isModelLoaded) {
        logger.i(
          '[BackgroundDetectionService] Background detection model loaded successfully.',
        );
        _modelLoaded = true;
      } else if (kDebugMode) {
        logger.w(
          '[BackgroundDetectionService] Background detection model FAILED to load.',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        logger.e(
          '[BackgroundDetectionService] Error loading model: $e\n$stackTrace',
        );

        // Additional debugging information
        try {
          final modelData = await rootBundle.load(_modelAssetPath);
          logger.i(
            '[BackgroundDetectionService] Model file exists and can be loaded, size: ${modelData.lengthInBytes} bytes',
          );

          // Try to check if it's a valid TFLite file
          if (modelData.lengthInBytes > 0) {
            final bytes = modelData.buffer.asUint8List();
            if (bytes.length >= 4) {
              final magic = String.fromCharCodes(bytes.take(4));
              logger.i('[BackgroundDetectionService] File magic bytes: $magic');
              if (magic == 'TFL3') {
                logger.i(
                  '[BackgroundDetectionService] File appears to be a valid TFLite model',
                );

                // Check TFLite version compatibility
                if (bytes.length >= 8) {
                  final versionBytes = bytes.sublist(4, 8);
                  final version = versionBytes.fold<int>(
                    0,
                    (prev, byte) => (prev << 8) | byte,
                  );
                  logger.i(
                    '[BackgroundDetectionService] TFLite version: $version',
                  );

                  if (version > 12) {
                    logger.w(
                      '[BackgroundDetectionService] Model uses TFLite version $version, which may not be compatible with current runtime',
                    );
                  }
                }
              } else {
                logger.w(
                  '[BackgroundDetectionService] File does not appear to be a valid TFLite model',
                );
              }
            }
          }
        } catch (fileError) {
          logger.e(
            '[BackgroundDetectionService] Error reading model file: $fileError',
          );
        }
      }
      _modelLoaded = false;
      rethrow;
    } finally {
      _isLoadingModel = false;
    }
  }

  /// Detect whether an image contains plant leaves
  /// Returns true if leaves are detected (confidence >= threshold), false otherwise
  ///
  /// [imageBytes] - Raw image bytes
  /// [confidenceThreshold] - Minimum confidence threshold (default: 0.6 = 60%)
  /// Returns: Map with 'hasLeaves' boolean and 'confidence' double
  Future<Map<String, dynamic>> detectLeaves({
    required Uint8List imageBytes,
    double confidenceThreshold = 0.6,
  }) async {
    try {
      // Try to load model if not loaded
      if (!_modelLoaded) {
        try {
          await loadModel();
        } catch (e) {
          if (kDebugMode) {
            logger.w(
              '[BackgroundDetectionService] TFLite model loading failed, using fallback detection: $e',
            );
          }
          // Use fallback detection when TFLite fails
          return _fallbackDetection(imageBytes, confidenceThreshold);
        }
      }

      if (!_modelLoaded || _interpreterWrapper == null) {
        if (kDebugMode) {
          logger.w(
            '[BackgroundDetectionService] Using fallback detection due to model loading issues',
          );
        }
        return _fallbackDetection(imageBytes, confidenceThreshold);
      }

      // Original TFLite detection logic
      return await _runTfliteDetection(imageBytes, confidenceThreshold);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        logger.e(
          '[BackgroundDetectionService] Error during detection: $e\n$stackTrace',
        );
      }
      // Fallback to basic detection
      return _fallbackDetection(imageBytes, confidenceThreshold);
    }
  }

  /// Fallback detection method when TFLite model fails
  Map<String, dynamic> _fallbackDetection(
    Uint8List imageBytes,
    double confidenceThreshold,
  ) {
    try {
      // Simple heuristic: check if image has enough non-black pixels
      // This is a very basic fallback and should be improved
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        return {
          'hasLeaves': false,
          'confidence': 0.0,
          'method': 'fallback_error',
        };
      }

      // Count non-black pixels (assuming leaves are not pure black)
      int nonBlackPixels = 0;
      int totalPixels = decodedImage.width * decodedImage.height;

      // More sophisticated pixel analysis
      int greenPixels = 0;
      int brightPixels = 0;

      for (int y = 0; y < decodedImage.height; y++) {
        for (int x = 0; x < decodedImage.width; x++) {
          final pixel = decodedImage.getPixel(x, y);

          // Check if pixel is not too dark (simple threshold)
          if (pixel.r > 30 || pixel.g > 30 || pixel.b > 30) {
            nonBlackPixels++;
          }

          // Check for green pixels (typical for leaves)
          if (pixel.g > pixel.r && pixel.g > pixel.b && pixel.g > 50) {
            greenPixels++;
          }

          // Check for bright pixels (good lighting)
          if (pixel.r > 100 && pixel.g > 100 && pixel.b > 100) {
            brightPixels++;
          }
        }
      }

      double nonBlackRatio = nonBlackPixels / totalPixels;
      double greenRatio = greenPixels / totalPixels;
      double brightRatio = brightPixels / totalPixels;

      // Simple logic: if image has content and some green, assume leaves
      bool hasLeaves = nonBlackRatio > 0.3 && greenRatio > 0.05;

      // Calculate background probability based on heuristics
      double backgroundProbability;
      if (hasLeaves) {
        // If we detect leaves, background probability should be low
        backgroundProbability = 0.3; // 30% background probability
      } else {
        // If no leaves detected, background probability should be high
        backgroundProbability = 0.9; // 90% background probability
      }

      if (kDebugMode) {
        logger.i(
          '[BackgroundDetectionService] Fallback detection: hasLeaves=$hasLeaves, backgroundProbability=${(backgroundProbability * 100).toStringAsFixed(1)}%, green=$greenRatio, nonBlack=$nonBlackRatio',
        );
      }

      return {
        'hasLeaves': hasLeaves,
        'backgroundProbability': backgroundProbability,
        'method': 'fallback_heuristic_hardcoded',
        'pixelRatio': nonBlackRatio,
        'greenRatio': greenRatio,
        'brightRatio': brightRatio,
        'note': 'Using heuristic-based background probability calculation',
      };
    } catch (e) {
      if (kDebugMode) {
        logger.e('[BackgroundDetectionService] Fallback detection failed: $e');
      }
      // Return a safe default - assume leaves are present to allow processing
      return {
        'hasLeaves':
            true, // Assume leaves are present to allow processing to continue
        'backgroundProbability':
            0.3, // Low background probability (30%) since we assume leaves are present
        'method': 'fallback_safe_default_hardcoded',
        'error': e.toString(),
        'note':
            'Using safe default: assuming leaves present with low background probability',
      };
    }
  }

  /// Run TFLite model detection
  Future<Map<String, dynamic>> _runTfliteDetection(
    Uint8List imageBytes,
    double confidenceThreshold,
  ) async {
    // Decode and preprocess image
    final img.Image? decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) throw Exception('Failed to decode image.');

    // Get model input requirements
    final inputTensor = _interpreterWrapper!.getInputTensor(0);
    final inputShape = inputTensor.shape;
    final inputHeight = inputShape[1]; // Should be 224
    final inputWidth = inputShape[2]; // Should be 224

    // Resize image to 224x224 (model input size)
    final img.Image resizedImage = img.copyResize(
      decodedImage,
      width: inputWidth,
      height: inputHeight,
    );

    // Normalize image to [0,1] range and prepare input buffer
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

    // Prepare output buffer (binary classification: 1 output)
    final outputTensor = _interpreterWrapper!.getOutputTensor(0);
    final outputBuffer = List.generate(
      outputTensor.shape[0],
      (_) => List.filled(outputTensor.shape[1], 0.0),
    );

    // Run inference
    _interpreterWrapper!.run(inputBuffer.buffer, outputBuffer);

    // Extract confidence score (sigmoid output)
    List<double> probabilities =
        (outputBuffer.first as List<dynamic>).cast<double>();
    double backgroundProbability =
        probabilities.first; // This is background probability

    // Determine if leaves are detected (low background probability = leaves present)
    bool hasLeaves = backgroundProbability < (1.0 - confidenceThreshold);

    if (kDebugMode) {
      logger.i(
        '[BackgroundDetectionService] TFLite detection result: hasLeaves=$hasLeaves, backgroundProbability=${(backgroundProbability * 100).toStringAsFixed(1)}%',
      );
    }

    return {
      'hasLeaves': hasLeaves,
      'backgroundProbability':
          backgroundProbability, // Model directly outputs background probability
      'method': 'tflite_model',
    };
  }

  /// Dispose of resources
  void dispose() {
    _interpreterWrapper?.close();
    _interpreterWrapper = null;
    _modelLoaded = false;
  }
}
