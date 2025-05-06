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
import 'dart:math';

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
      // Log the raw content read from the file
      if (kDebugMode) {
        print(
          '[DetectionService] Raw labels content read (length: ${rawLabels.length}):\n"$rawLabels"',
        );
        // Check for common invisible characters
        if (rawLabels.contains('\r') && !rawLabels.contains('\n'))
          print(
            '[DetectionService] WARNING: Label file might be using old Mac line endings (\r).',
          );
        if (rawLabels.startsWith('\uFEFF'))
          print(
            '[DetectionService] WARNING: Label file starts with BOM character.',
          );
      }

      _labels =
          rawLabels
              .split(RegExp(r'\r?\n'))
              .where((e) => e.trim().isNotEmpty)
              .map(
                (label) => label.replaceAll(' ', '_'),
              ) // Replace spaces with underscores
              .toList();
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
        // Print the actual labels for debugging
        if (_labels != null && _labels!.isNotEmpty) {
          print('[DetectionService] First label: "${_labels!.first}"');
          if (_labels!.length > 1) {
            print('[DetectionService] Second label: "${_labels![1]}"');
          }
        } else {
          print(
            '[DetectionService] WARNING: No labels loaded or empty labels list',
          );
        }
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

      // Determine model input dimensions and type
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;
      final inputType = inputTensor.type; // TensorType.uint8 or .float32
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];

      // Resize the image to expected input size
      final resizedImage = img.copyResize(
        decodedImage,
        width: inputWidth,
        height: inputHeight,
      );

      // Print image format details for debugging
      if (kDebugMode) {
        print(
          '[DetectionService] Resized image width: ${resizedImage.width}, height: ${resizedImage.height}',
        );
        print('[DetectionService] Image format: ${resizedImage.format}');
      }

      // Prepare input buffer based on tensor type
      // NOTE: We support both quantized (uint8) and float32 models.
      Object inputBuffer;
      if (inputType == TensorType.uint8) {
        // Extract raw bytes from the image
        final bytes = resizedImage.getBytes();
        if (kDebugMode) {
          print('[DetectionService] Got RGB bytes: ${bytes.length} bytes');
        }

        // Copy bytes to input buffer in correct format
        final Uint8List buffer = Uint8List(inputHeight * inputWidth * 3);
        for (int i = 0; i < bytes.length && i < buffer.length; i++) {
          buffer[i] = bytes[i];
        }

        inputBuffer = buffer.reshape([1, inputHeight, inputWidth, 3]);
      } else if (inputType == TensorType.float32) {
        // Float model – determine normalisation. Common options:
        // 1) 0-1  (divide by 255)
        // 2) ‑1-1 ( (pixel-127.5)/127.5 )
        // We'll attempt option (1) first but expose both for experimentation.
        const bool useNegativeOneToOne = false; // flip if needed later

        // Extract raw bytes from the image
        final bytes = resizedImage.getBytes();
        final Float32List buffer = Float32List(inputHeight * inputWidth * 3);
        for (int i = 0; i < bytes.length && i < buffer.length; i++) {
          double pixelValue = bytes[i].toDouble();
          if (useNegativeOneToOne) {
            buffer[i] = (pixelValue - 127.5) / 127.5;
          } else {
            buffer[i] = pixelValue / 255.0;
          }
        }
        inputBuffer = buffer.reshape([1, inputHeight, inputWidth, 3]);
      } else {
        throw Exception(
          '[DetectionService] Unsupported input tensor type: $inputType',
        );
      }

      // 2. Detection
      if (kDebugMode) {
        print('[DetectionService] Running model inference for $plantId...');
      }

      // Prepare output buffer dynamically according to tensor type and shape
      final outputTensor = _interpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape; // e.g., [1, numClasses]
      final outputType = outputTensor.type;

      Object outputBuffer;
      if (outputType == TensorType.uint8) {
        outputBuffer = Uint8List(
          outputShape.reduce((a, b) => a * b),
        ).reshape(outputShape);
      } else if (outputType == TensorType.float32) {
        outputBuffer = Float32List(
          outputShape.reduce((a, b) => a * b),
        ).reshape(outputShape);
      } else {
        throw Exception(
          '[DetectionService] Unsupported output tensor type: $outputType',
        );
      }

      if (kDebugMode) {
        print('[DetectionService] Input tensor shape: ${inputShape}');
        print(
          '[DetectionService] Input buffer type: ${inputBuffer.runtimeType}',
        );
        print('[DetectionService] Output tensor shape: ${outputShape}');
        print(
          '[DetectionService] Output buffer type: ${outputBuffer.runtimeType}',
        );
        try {
          // Print dimensions based on actual type
          if (outputBuffer is List &&
              outputBuffer.isNotEmpty &&
              outputBuffer.first is List) {
            print(
              '[DetectionService] Output buffer dimensions (nested list): [${outputBuffer.length}, ${outputBuffer.first.length}]',
            );
          } else if (outputBuffer is List) {
            print(
              '[DetectionService] Output buffer dimensions (flat list): [${outputBuffer.length}]',
            );
          }
        } catch (e) {
          print('[DetectionService] Could not print output buffer shape: $e');
        }
      }

      try {
        // Run the inference
        _interpreter!.run(inputBuffer, outputBuffer);
        if (kDebugMode) {
          print('[DetectionService] Inference completed successfully');

          // Debug the output buffer
          if (outputType == TensorType.uint8) {
            final buffer = outputBuffer as Uint8List;
            print(
              '[DetectionService] Sample of output buffer (uint8): ${buffer.take(10).toList()}',
            );
          } else if (outputType == TensorType.float32) {
            // Handle nested list structure for float32 output
            final nestedList = outputBuffer as List<List<dynamic>>;
            if (nestedList.isNotEmpty && nestedList.first.isNotEmpty) {
              // Convert inner list to List<double> for printing
              final scores =
                  nestedList.first.map((e) => (e as num).toDouble()).toList();
              print(
                '[DetectionService] Sample of output buffer (float32 - from nested): ${scores.take(10).toList()}',
              );
            } else {
              print(
                '[DetectionService] Output buffer (float32) is empty or has unexpected structure.',
              );
            }
          }
        }
      } catch (e, st) {
        if (kDebugMode) {
          print('[DetectionService] INFERENCE ERROR: $e');
          print('[DetectionService] Stack trace: $st');
        }
        // When inference fails, return empty results instead of throwing
        // This prevents the plant from getting stuck in "error" status
        return [];
      }

      // 3. Postprocessing
      List<DetectionResult> results = [];

      try {
        if (kDebugMode) {
          print('[DetectionService] Starting postprocessing of results');
        }

        // Depending on output type, build the results
        if (outputType == TensorType.uint8) {
          final buffer = outputBuffer as Uint8List;
          // Process the output scores
          int numClasses = outputShape.last;
          // Process scores (outputBuffer contains raw scores)
          List<double> scores = List<double>.filled(numClasses, 0.0);

          for (int i = 0; i < numClasses; i++) {
            scores[i] =
                buffer[i].toDouble() / 255.0; // Convert uint8 to probability
          }

          // Get indices sorted by confidence (highest first)
          List<int> indices = List.generate(numClasses, (i) => i);
          indices.sort((a, b) => scores[b].compareTo(scores[a]));

          // Create results for top predictions
          for (int i = 0; i < min(5, numClasses); i++) {
            int classIndex = indices[i];
            double confidence = scores[classIndex];

            // Only include if confidence is above a very low threshold to exclude true zeros
            if (confidence > 0.01) {
              results.add(
                DetectionResult(
                  diseaseName: _labels![classIndex],
                  confidence: confidence,
                  boundingBox:
                      null, // Not using bounding boxes for disease models
                ),
              );
            }
          }
        } else if (outputType == TensorType.float32) {
          // Handle nested list output for float32
          final nestedList = outputBuffer as List<List<dynamic>>;
          if (nestedList.isEmpty || nestedList.first.isEmpty) {
            if (kDebugMode)
              print(
                '[DetectionService] WARNING: Float32 output buffer has unexpected empty structure.',
              );
            // Return empty results if structure is wrong
            return [];
          }

          // Extract the actual scores (likely from the first inner list)
          final scoresList =
              nestedList.first.map((e) => (e as num).toDouble()).toList();

          // Process the output scores
          int numClasses =
              scoresList.length; // Use length of the actual scores list
          if (numClasses != outputShape.last) {
            if (kDebugMode)
              print(
                '[DetectionService] WARNING: Number of scores (${scoresList.length}) does not match expected output shape (${outputShape.last})',
              );
            // Optionally handle this mismatch, e.g., by using the shorter length
            numClasses = min(numClasses, outputShape.last);
          }

          // Get indices sorted by confidence (highest first)
          List<int> indices = List.generate(numClasses, (i) => i);
          indices.sort((a, b) => scoresList[b].compareTo(scoresList[a]));

          // Create results for top predictions
          for (int i = 0; i < min(5, numClasses); i++) {
            int classIndex = indices[i];
            double confidence = scoresList[classIndex];

            // Only include if confidence is above a very low threshold to exclude true zeros
            if (confidence > 0.01) {
              // Check if classIndex is valid for _labels
              if (classIndex < 0 || classIndex >= (_labels?.length ?? 0)) {
                if (kDebugMode)
                  print(
                    '[DetectionService] WARNING: Invalid classIndex ($classIndex) for labels list length (${_labels?.length}). Skipping result.',
                  );
                continue; // Skip this result
              }
              results.add(
                DetectionResult(
                  diseaseName: _labels![classIndex],
                  confidence: confidence,
                  boundingBox:
                      null, // Not using bounding boxes for disease models
                ),
              );
            }
          }
        }

        // Always return at least the top result even if below threshold
        if (results.isEmpty && outputShape.last > 0) {
          if (kDebugMode) {
            print(
              '[DetectionService] No results above threshold, forcing at least one result',
            );
          }

          // Find the highest confidence class
          if (outputType == TensorType.uint8) {
            final buffer = outputBuffer as Uint8List;
            int bestClassIndex = 0;
            int bestScore = 0;

            for (int i = 0; i < outputShape.last; i++) {
              if (buffer[i] > bestScore) {
                bestScore = buffer[i];
                bestClassIndex = i;
              }
            }

            results.add(
              DetectionResult(
                diseaseName: _labels![bestClassIndex],
                confidence: bestScore / 255.0,
                boundingBox: null,
              ),
            );
          } else if (outputType == TensorType.float32) {
            // Handle nested list structure for float32
            final nestedList = outputBuffer as List<List<dynamic>>;
            if (nestedList.isEmpty || nestedList.first.isEmpty) {
              if (kDebugMode)
                print(
                  '[DetectionService] WARNING: Cannot force result, float32 output buffer is empty.',
                );
              return []; // Can't force a result if buffer is empty
            }
            final scoresList =
                nestedList.first.map((e) => (e as num).toDouble()).toList();

            int bestClassIndex = 0;
            double bestScore = -double.infinity;
            int numScoresToConsider = scoresList.length;

            for (int i = 0; i < numScoresToConsider; i++) {
              if (scoresList[i] > bestScore) {
                bestScore = scoresList[i];
                bestClassIndex = i;
              }
            }

            // Check if bestClassIndex is valid before accessing _labels
            if (bestClassIndex < 0 ||
                bestClassIndex >= (_labels?.length ?? 0)) {
              if (kDebugMode)
                print(
                  '[DetectionService] WARNING: Invalid bestClassIndex ($bestClassIndex) for labels list length (${_labels?.length}) when forcing result.',
                );
              return []; // Return empty if index is invalid
            }

            results.add(
              DetectionResult(
                diseaseName: _labels![bestClassIndex],
                confidence: bestScore,
                boundingBox: null,
              ),
            );
          }
        }

        if (kDebugMode) {
          print(
            '[DetectionService] Postprocessing complete. Found ${results.length} results.',
          );
          if (results.isNotEmpty) {
            print(
              '[DetectionService] Top result: ${results.first.diseaseName} (${results.first.confidence})',
            );
          }
        }

        return results;
      } catch (e, st) {
        if (kDebugMode) {
          print('[DetectionService] ERROR in postprocessing: $e');
          print('[DetectionService] Stack trace: $st');
        }

        // Return empty results on error, don't throw
        return [];
      }
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
