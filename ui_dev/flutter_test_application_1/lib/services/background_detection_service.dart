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

  /// If the model has a **single sigmoid** output (1x1), set this to true if that
  /// output represents P(leaf). If it represents P(background), leave as false.
  /// Given your filename and previous behavior, default = false.
  static const bool _singleSigmoidIsLeafProb = false;

  TfliteInterpreterWrapper? _interpreterWrapper;
  bool _isLoadingModel = false;
  bool _modelLoaded = false;

  static int _toByte(num v) {
    // Fast, safe map to 0..255 as int
    final int iv = v is int ? v : v.round();
    if (iv < 0) return 0;
    if (iv > 255) return 255;
    return iv;
  }

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
  /// Returns: Map with 'hasLeaves' boolean and probabilities
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

      // Robust TFLite detection logic
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
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        return {
          'hasLeaves': false,
          'leafProbability': 0.0,
          'backgroundProbability': 1.0,
          'method': 'fallback_error',
        };
      }

      // Heuristic: content + green-ness
      int nonBlackPixels = 0;
      int totalPixels = decodedImage.width * decodedImage.height;

      int greenPixels = 0;
      int brightPixels = 0;

      for (int y = 0; y < decodedImage.height; y++) {
        for (int x = 0; x < decodedImage.width; x++) {
          final pixel = decodedImage.getPixel(x, y);

          if (pixel.r > 30 || pixel.g > 30 || pixel.b > 30) {
            nonBlackPixels++;
          }

          if (pixel.g > pixel.r && pixel.g > pixel.b && pixel.g > 50) {
            greenPixels++;
          }

          if (pixel.r > 100 && pixel.g > 100 && pixel.b > 100) {
            brightPixels++;
          }
        }
      }

      final double nonBlackRatio = nonBlackPixels / totalPixels;
      final double greenRatio = greenPixels / totalPixels;
      final double brightRatio = brightPixels / totalPixels;

      // Simple logic: if image has content and some green, assume leaves
      final bool hasLeaves = nonBlackRatio > 0.3 && greenRatio > 0.05;

      // Heuristic leaf prob centered near 0.7 when positive
      final double leafProb = hasLeaves ? 0.7 : 0.3;
      final double backgroundProb = 1.0 - leafProb;

      if (kDebugMode) {
        logger.i(
          '[BackgroundDetectionService] Fallback heuristic: nonBlackRatio=$nonBlackRatio, '
          'greenRatio=$greenRatio, brightRatio=$brightRatio, hasLeaves=$hasLeaves, '
          'leafProb=$leafProb',
        );
      }

      return {
        'hasLeaves': hasLeaves,
        'leafProbability': leafProb,
        'backgroundProbability': backgroundProb,
        'method': 'fallback_heuristic',
        'pixelRatio': nonBlackRatio,
        'greenRatio': greenRatio,
        'brightRatio': brightRatio,
        'note': 'Heuristic used due to TFLite load/run issue',
      };
    } catch (e) {
      if (kDebugMode) {
        logger.e('[BackgroundDetectionService] Fallback detection failed: $e');
      }
      return {
        'hasLeaves': true,
        'leafProbability': 0.7,
        'backgroundProbability': 0.3,
        'method': 'fallback_safe_default',
        'error': e.toString(),
        'note': 'Safe default used due to fallback error',
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
    final dynamic inputTensor = _interpreterWrapper!.getInputTensor(0);
    final List<int> inputShape =
        (inputTensor.shape as List).map((e) => e as int).toList();
    final int inputHeight = inputShape[1]; // e.g., 224
    final int inputWidth = inputShape[2]; // e.g., 224

    // Resize image to model input size
    final img.Image resizedImage = img.copyResize(
      decodedImage,
      width: inputWidth,
      height: inputHeight,
    );

    // Determine input type (quantized or float)
    final String inTypeStr = inputTensor.type.toString().toLowerCase();
    final bool inIsUint8 = inTypeStr.contains('uint8');
    final bool inIsFloat32 =
        inTypeStr.contains('float') || inTypeStr.contains('float32');

    // Try to read input quantization params if available
    double inScale = 1.0 / 255.0;
    int inZeroPoint = 0;
    try {
      // Try common shapes of metadata
      final q =
          inputTensor.quantizationParameters ??
          inputTensor.quantization;
      if (q != null) {
        // Some wrappers expose as {scale, zeroPoint} or arrays
        if (q.scale is num) inScale = (q.scale as num).toDouble();
        if (q.zeroPoint is int) inZeroPoint = q.zeroPoint as int;
        // If scale is 0 (rare), fall back
        if (inScale == 0) inScale = 1.0 / 255.0;
      }
    } catch (_) {
      // Keep defaults
    }

    // Build input buffer according to type
    ByteBuffer inputByteBuffer;
    if (inIsUint8) {
      // Quantized input: Uint8List with optional quantization mapping
      final Uint8List input = Uint8List(inputHeight * inputWidth * 3);
      int i = 0;
      for (int y = 0; y < inputHeight; y++) {
        for (int x = 0; x < inputWidth; x++) {
          final p = resizedImage.getPixel(x, y);
          // Convert RGB [0,255] -> quantized domain if non-default qparams present
          // value_q = round(value_f / scale + zero_point)
          // Here value_f is simply raw 0..255; if scale ~ 1/255 and zero_point 0, this is identity.

          // p.r/g/b are `num` -> convert to 0..255 ints
          int r = _toByte(p.r);
          int g = _toByte(p.g);
          int b = _toByte(p.b);

          if (!(inScale == (1.0 / 255.0) && inZeroPoint == 0)) {
            // Map from [0..255] float space to quant domain
            r = _quantize255ToUint8(r.toDouble(), inScale, inZeroPoint);
            g = _quantize255ToUint8(g.toDouble(), inScale, inZeroPoint);
            b = _quantize255ToUint8(b.toDouble(), inScale, inZeroPoint);
          }

          input[i++] = r;
          input[i++] = g;
          input[i++] = b;
        }
      }
      inputByteBuffer = input.buffer;
    } else if (inIsFloat32) {
      // Float input: normalize to [0,1]
      final Float32List input = Float32List(
        1 * inputHeight * inputWidth * 3,
      ); // NHWC with N=1
      int bufferIndex = 0;
      for (int y = 0; y < inputHeight; y++) {
        for (int x = 0; x < inputWidth; x++) {
          final p = resizedImage.getPixel(x, y);
          input[bufferIndex++] = p.r / 255.0;
          input[bufferIndex++] = p.g / 255.0;
          input[bufferIndex++] = p.b / 255.0;
        }
      }
      inputByteBuffer = input.buffer;
    } else {
      throw Exception('Unsupported input tensor type: ${inputTensor.type}');
    }

    // Prepare output buffer
    final dynamic outputTensor = _interpreterWrapper!.getOutputTensor(0);
    final List<int> outShape =
        (outputTensor.shape as List).map((e) => e as int).toList();

    // We expect [1,1] (single sigmoid) or [1,2] (softmax)
    if (outShape.length != 2 || outShape.first != 1) {
      throw Exception('Unexpected output shape: $outShape');
    }
    final int outSize = outShape[1];

    // Allocate a nested list of doubles to remain compatible with wrapper
    final List<List<double>> outputBuffer = List.generate(
      1,
      (_) => List.filled(outSize, 0.0),
    );

    // Run inference
    _interpreterWrapper!.run(inputByteBuffer, outputBuffer);

    // Extract raw outputs as doubles (wrapper may already dequantize; handle both)
    final List<double> rawOut =
        (outputBuffer.first).map((e) => e.toDouble()).toList();

    // If output is quantized uint8 in some wrappers, we might need to dequantize.
    // Try to read output quantization params; if they exist and look valid, dequantize.
    double outScale = 1.0;
    int outZeroPoint = 0;
    bool needDequantize = false;
    try {
      final q =
          outputTensor.quantizationParameters ??
          outputTensor.quantization;
      if (q != null && q.scale is num) {
        outScale = (q.scale as num).toDouble();
        if (q.zeroPoint is int) outZeroPoint = q.zeroPoint as int;
        // If scale seems plausible (e.g., ~1/256), attempt dequantization.
        if (outScale > 0 && (outScale < 1.0)) {
          needDequantize = true;
        }
      }
    } catch (_) {
      // ignore, assume already float
    }

    final List<double> probs =
        needDequantize
            ? rawOut
                .map((v) => outScale * ((v as num).toDouble() - outZeroPoint))
                .toList()
            : rawOut;

    // Convert to leaf/background probabilities depending on head
    double leafProb;
    double backgroundProb;

    if (outSize == 2) {
      // Assume [P(background), P(leaf)]
      backgroundProb = _clip01(probs[0]);
      leafProb = _clip01(probs[1]);
    } else if (outSize == 1) {
      // Single sigmoid
      final double p = _clip01(probs[0]);
      if (_singleSigmoidIsLeafProb) {
        leafProb = p;
        backgroundProb = 1.0 - p;
      } else {
        backgroundProb = p;
        leafProb = 1.0 - p;
      }
    } else {
      throw Exception('Unsupported number of outputs: $outSize');
    }

    final bool hasLeaves = leafProb >= confidenceThreshold;

    if (kDebugMode) {
      logger.i(
        '[BackgroundDetectionService] TFLite result: '
        'leafProb=${(leafProb * 100).toStringAsFixed(1)}%, '
        'backgroundProb=${(backgroundProb * 100).toStringAsFixed(1)}%, '
        'hasLeaves=$hasLeaves (threshold=${(confidenceThreshold * 100).toStringAsFixed(0)}%)',
      );
    }

    return {
      'hasLeaves': hasLeaves,
      'leafProbability': leafProb,
      'backgroundProbability': backgroundProb,
      'method': 'tflite_model',
      'head': outSize == 2 ? 'softmax_2' : 'sigmoid_1',
    };
  }

  static int _quantize255ToUint8(double value255, double scale, int zeroPoint) {
    // Map [0..255] float domain to quantized domain
    final double q = (value255 / 255.0) / scale + zeroPoint;
    return q.round().clamp(0, 255);
  }

  static double _clip01(double x) =>
      x.isNaN ? 0.0 : (x < 0.0 ? 0.0 : (x > 1.0 ? 1.0 : x));

  /// Dispose of resources
  void dispose() {
    _interpreterWrapper?.close();
    _interpreterWrapper = null;
    _modelLoaded = false;
  }
}
