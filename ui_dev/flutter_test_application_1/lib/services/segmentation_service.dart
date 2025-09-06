import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test_application_1/utils/logger.dart';
import 'package:flutter_test_application_1/services/tflite_interop/tflite_wrapper.dart';

/// A service that handles YOLO-based image segmentation using TFLite.
/// Supports single-image segmentation with mask generation.
class SegmentationService {
  // Singleton implementation
  static final SegmentationService _instance = SegmentationService._internal();
  factory SegmentationService() => _instance;
  SegmentationService._internal();

  // Model configuration constants
  static const String _modelAssetPath = 'assets/models/best_float32.tflite';
  static const int INPUT_SIZE = 640; // Model input size

  TfliteInterpreter? _interpreter;
  bool _modelLoaded = false;
  bool _isLoadingModel = false;

  bool get isModelLoaded => _modelLoaded;

  // Sigmoid activation function for mask probability
  double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  /// Loads and initializes the TFLite model
  Future<void> loadModel() async {
    if (_modelLoaded || _isLoadingModel) return;

    _isLoadingModel = true;
    if (kDebugMode) {
      logger.i('[SegmentationService] Loading model...');
    }

    try {
      _interpreter = TfliteInterpreter();
      final options = TfliteOptions()..threads = 2;
      await _interpreter!.loadModel(_modelAssetPath, options: options);

      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape; // [1,640,640,3]

      if (kDebugMode) {
        logger.i(
          '[SegmentationService] Model loaded. Input shape: $inputShape',
        );
      }

      _modelLoaded = true;
    } catch (e, st) {
      if (kDebugMode) {
        logger.e('[SegmentationService] Model loading failed: $e\n$st');
      }
      _modelLoaded = false;
      rethrow;
    } finally {
      _isLoadingModel = false;
    }
  }

  /// Preprocess to nested 4D list [1, H, W, 3] with values in [0,1]
  List<List<List<List<double>>>> _preprocessImageNested(img.Image image) {
    final resized = img.copyResize(
      image,
      width: INPUT_SIZE,
      height: INPUT_SIZE,
      interpolation: img.Interpolation.linear,
    );
    return [
      List.generate(INPUT_SIZE, (y) {
        return List.generate(INPUT_SIZE, (x) {
          final p = resized.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        });
      }),
    ];
  }

  /// Decode mask from proto HxWxC and coeff C
  List<List<double>> _decodeMaskFromNested(
    List<List<List<double>>> protoHWxC,
    List<double> coeff,
    int protoH,
    int protoW,
    int protoC,
  ) {
    return List.generate(protoH, (y) {
      return List.generate(protoW, (x) {
        double sum = 0.0;
        final pc = protoHWxC[y][x]; // length protoC
        for (int c = 0; c < protoC; c++) {
          sum += pc[c] * coeff[c];
        }
        return _sigmoid(sum);
      });
    });
  }

  /// Upscale a probability mask (nearest-neighbor) to INPUT_SIZE
  List<List<double>> _upsampleMask(List<List<double>> mask, int inH, int inW) {
    return List.generate(INPUT_SIZE, (y) {
      final srcY = (y * inH / INPUT_SIZE).floor().clamp(0, inH - 1);
      return List.generate(INPUT_SIZE, (x) {
        final srcX = (x * inW / INPUT_SIZE).floor().clamp(0, inW - 1);
        return mask[srcY][srcX];
      });
    });
  }

  /// Apply a probability mask to an image and produce a masked image
  img.Image _applyMaskToImage(List<List<double>> probMask, img.Image original) {
    final masked = img.Image(width: INPUT_SIZE, height: INPUT_SIZE);
    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        if (probMask[y][x] > 0.5) {
          masked.setPixel(x, y, original.getPixel(x, y));
        } else {
          masked.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
    }
    return masked;
  }

  /// Performs segmentation on an input image
  Future<File> segment(File inputFile) async {
    if (!_modelLoaded) {
      await loadModel();
      if (!_modelLoaded || _interpreter == null) {
        throw Exception('Failed to load segmentation model');
      }
    }

    try {
      // Read & preprocess
      final imgBytes = await inputFile.readAsBytes();
      final decoded = img.decodeImage(imgBytes);
      if (decoded == null) throw Exception('Failed to decode image');
      final inputNested = _preprocessImageNested(decoded); // [1,H,W,3]

      // Prepare outputs according to model output shapes
      final predTensor = _interpreter!.getOutputTensor(0); // [1,37,8400]
      final protoTensor = _interpreter!.getOutputTensor(1); // [1,160,160,32]

      final predShape = predTensor.shape;
      final protoShape = protoTensor.shape;
      final batchP = predShape[0]; // 1
      final channels = predShape[1]; // 37
      final anchors = predShape[2]; // 8400
      final batchQ = protoShape[0]; // 1
      final protoH = protoShape[1]; // 160
      final protoW = protoShape[2]; // 160
      final protoC = protoShape[3]; // 32

      // Allocate nested outputs as per tflite_flutter expectation
      final predOut = List.generate(
        batchP,
        (_) => List.generate(channels, (_) => List.filled(anchors, 0.0)),
      );
      final protoOut = List.generate(
        batchQ,
        (_) => List.generate(
          protoH,
          (_) => List.generate(protoW, (_) => List.filled(protoC, 0.0)),
        ),
      );

      // Run: inputs as List, outputs as Map<int,Object> (nested lists)
      final outputs = <int, Object>{0: predOut, 1: protoOut};
      _interpreter!.runForMultipleInputs([inputNested], outputs);

      // Parse predOut: shape [1][37][8400]
      final pred0 = predOut[0];
      double bestScore = -1.0;
      int bestIdx = -1;
      final bestCoeff = List<double>.filled(protoC, 0.0);
      for (int a = 0; a < anchors; a++) {
        final score = pred0[4][a];
        if (score > bestScore) {
          bestScore = score;
          bestIdx = a;
          for (int k = 0; k < protoC; k++) {
            bestCoeff[k] = pred0[5 + k][a];
          }
        }
      }
      if (bestIdx < 0) {
        throw Exception('No valid detections found');
      }

      // Decode and upscale mask from protoOut: [1][160][160][32]
      final proto0 = protoOut[0];
      final lowResMask = _decodeMaskFromNested(
        proto0,
        bestCoeff,
        protoH,
        protoW,
        protoC,
      );
      final upMask = _upsampleMask(lowResMask, protoH, protoW);

      // Apply mask to resized original
      final resizedForOverlay = img.copyResize(
        decoded,
        width: INPUT_SIZE,
        height: INPUT_SIZE,
      );
      final maskImage = _applyMaskToImage(upMask, resizedForOverlay);

      // Save
      final outputFile = File('${Directory.systemTemp.path}/mask_result.png');
      await outputFile.writeAsBytes(img.encodePng(maskImage));
      if (kDebugMode) {
        logger.i('[SegmentationService] Mask saved (confidence: $bestScore)');
      }
      return outputFile;
    } catch (e, st) {
      if (kDebugMode) {
        logger.e('[SegmentationService] Segmentation failed: $e\n$st');
      }
      rethrow;
    }
  }

  /// Releases resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
  }
}
