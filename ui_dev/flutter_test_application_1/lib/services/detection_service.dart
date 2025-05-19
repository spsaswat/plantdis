import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test_application_1/models/detection_result.dart';
import 'package:flutter/foundation.dart'; // Import for kIsWeb and kDebugMode
import 'package:image/image.dart' as img; // image package is used.
import 'dart:async';
import 'dart:math'; // For Random
import 'package:flutter_test_application_1/models/analysis_progress.dart'; // Import for AnalysisProgress and AnalysisStage

// Conditional imports for dart:js and dart:html for web
import 'dart:js' if (dart.library.io) 'dart:io' as js; // Use a dummy for non-web
import 'dart:html' if (dart.library.io) 'dart:io' as html; // Use a dummy for non-web
import 'dart:js_util' if (dart.library.io) 'dart:io' as js_util; // Use a dummy for non-web

// Import the TFLite interop layer
import 'package:flutter_test_application_1/services/tflite_interop/tflite_wrapper.dart';

// Import implementations only when needed and using conditional imports
// We don't need to import these directly, they're exported via tflite_wrapper.dart
// import 'package:flutter_test_application_1/services/tflite_interop/tflite_mobile.dart' if (dart.library.html) 'package:flutter_test_application_1/services/tflite_interop/tflite_web.dart';

class DetectionService {
  // --- Singleton Pattern Start ---
  static final DetectionService _instance = DetectionService._internal();

  factory DetectionService() {
    return _instance;
  }

  DetectionService._internal();
  // --- Singleton Pattern End ---

  // Model and labels paths
  static const String _tfliteModelPath =
      'assets/models/plant_disease_model.tflite';
  static const String _tfliteLabelsPath = 'assets/models/labels_village.txt';

  // Web model (TF.js) paths
  static const String _webModelPath = 'assets/models/model.json';
  static const String _webLabelsPath = 'assets/models/labels_village.txt';

  // Use the TFLite wrapper for the interpreter
  TfliteInterpreterWrapper? _interpreterWrapper;
  // TODO: Add variables for TF.js model if needed by the TF.js library
  // e.g., var _tfjsModel;

  List<String>? _labels;
  bool _modelLoaded =
      false; // Represents if *either* TFLite (via wrapper) or TF.js model is loaded
  bool _isLoadingModel = false;

  bool get isModelLoaded => _modelLoaded;

  Future<void> loadModel() async {
    if (_modelLoaded) {
      if (kDebugMode) print('[DetectionService] Model already loaded.');
      return;
    }
    if (_isLoadingModel) {
      if (kDebugMode)
        print('[DetectionService] Model loading already in progress.');
      return;
    }

    _isLoadingModel = true;
    if (kDebugMode) print('[DetectionService] Starting to load model...');

    try {
      if (kIsWeb) {
        if (kDebugMode) print('[DetectionService WEB] Loading TF.js model and labels...');
        try {
          // Check if TF.js and our custom JS functions are available
          if (js.context['tf'] == null) {
            throw Exception('TensorFlow.js library (tf) not found in JavaScript context.');
          }
          if (js.context['loadTFJSModel'] == null || js.context['runTFJSModelOnImageData'] == null) {
            throw Exception('Required JavaScript functions (loadTFJSModel or runTFJSModelOnImageData) not found.');
          }
          // Check for the new wrapper function
          if (js.context['getLoadTFJSModelPromise'] == null) {
            throw Exception('Required JavaScript function getLoadTFJSModelPromise not found.');
          }

          var loadModelPromise = js_util.callMethod(js_util.globalThis, 'getLoadTFJSModelPromise', [_webModelPath]);
          if (loadModelPromise == null) {
            throw Exception('JavaScript getLoadTFJSModelPromise did not return a Promise (returned null).');
          }
          if (js_util.getProperty(loadModelPromise, 'then') == null) {
            throw Exception('JavaScript getLoadTFJSModelPromise did not return a valid Promise (missing .then method).');
          }
          
          bool jsPromiseResolvedValue = await js_util.promiseToFuture<bool>(loadModelPromise);
          if (kDebugMode) {
            print('[DetectionService WEB] JavaScript getLoadTFJSModelPromise resolved, returned: $jsPromiseResolvedValue');
          }

          if (jsPromiseResolvedValue is bool && jsPromiseResolvedValue == true) {
            // The JS function *believes* it succeeded.
            // NOW, critically, check the state of window.loadedTfjsModel FROM DART
            var jsModel = js_util.getProperty(js_util.globalThis, 'loadedTfjsModel');
            
            if (jsModel == null) {
              var jsModelType = jsModel?.runtimeType;
              var jsModelTypeOfFromJS = "not a JS object or error getting type";
              // It's tricky to get the JS type of a null JS object from Dart directly
              // We mostly rely on the console logs from JS side for 'typeof null' which is 'object'

              if (kDebugMode) {
                print('[DetectionService WEB] WARNING: JS promise resolved true ($jsPromiseResolvedValue), but window.loadedTfjsModel is null/undefined when checked by Dart.');
                print('[DetectionService WEB] Dart sees jsModel as: $jsModel, Dart type for jsModel: $jsModelType');
              }
              _modelLoaded = false; // Ensure it's false
              throw StateError('[DetectionService WEB] State Inconsistency: JS reported model load success (returned true), but window.loadedTfjsModel is null/undefined when checked by Dart immediately after.');
            } else {
              if (kDebugMode) {
                String jsModelDartType = jsModel.runtimeType.toString();
                String jsModelJsType = "unknown";
                try {
                  if (js_util.hasProperty(jsModel, 'constructor') && js_util.getProperty(jsModel, 'constructor') != null) {
                     jsModelJsType = js_util.getProperty(js_util.getProperty(jsModel, 'constructor'), 'name')?.toString() ?? "null_constructor_name";
                  } else {
                    jsModelJsType = "no_constructor_property";
                  }
                } catch (e) {
                  jsModelJsType = "error_getting_js_type: $e";
                }
                print('[DetectionService WEB] window.loadedTfjsModel is accessible and not null. Dart type: $jsModelDartType, JS type via constructor.name: $jsModelJsType');
              }
              _modelLoaded = true; // Set model loaded successfully
            }
          } else {
            // JS Promise resolved, but not to 'true'
            if (kDebugMode) print('[DetectionService WEB] JavaScript getLoadTFJSModelPromise resolved, but returned: $jsPromiseResolvedValue instead of true.');
            _modelLoaded = false;
            throw Exception('JavaScript getLoadTFJSModelPromise did not return true. Actual: $jsPromiseResolvedValue');
          }

          // Load labels only if model loading was truly successful and confirmed
          if (_modelLoaded) {
            if (kDebugMode) print('[DetectionService WEB] Proceeding to load labels as _modelLoaded is true.');
            final rawLabels = await rootBundle.loadString(_webLabelsPath);
            _labels = rawLabels.split(RegExp(r'\r?\n')).where((e) => e.trim().isNotEmpty).toList();
            if (kDebugMode) {
                print('[DetectionService WEB] Dart _modelLoaded flag is true. Labels loaded: ${_labels?.length}');
            }
          } else {
             if (kDebugMode) print('[DetectionService WEB] Skipping label loading as _modelLoaded is false.');
          }

        } catch (e, s) {
          _modelLoaded = false; // Ensure it's false on any error during this specific web load block
          if (kDebugMode) print('[DetectionService WEB] Error in web model loading block: $e\n$s');
          rethrow; // Rethrow to be caught by the outer try-catch
        }
      } else {
        // --- Load TFLite Model for Mobile/Desktop via Wrapper ---
        if (kDebugMode)
          print(
            '[DetectionService NATIVE] Loading TFLite model via wrapper...',
          );

        // Platform-specific code for non-web - This section doesn't run on web
        try {
          if (!kIsWeb) {
            // Ensure this block only runs on non-web
            _interpreterWrapper =
                TfliteInterpreterWrapper(); // Uses the factory

            final options = TfliteInterpreterOptions(); // Uses the factory
            options.threads = 2;

            await _interpreterWrapper!.loadModel(
              _tfliteModelPath,
              options: options,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print(
              '[DetectionService] Error creating or loading native interpreter: $e',
            );
          }
          rethrow;
        }

        // This part for loading labels and checking model status is common
        // but _interpreterWrapper would be null on web if we reached here without web-specific loading.
        // The outer kIsWeb check should prevent this path for web.
        if (!kIsWeb) {
          // Condition this part as well
          final rawLabels = await rootBundle.loadString(_tfliteLabelsPath);
          _labels =
              rawLabels
                  .split(RegExp(r'\r?\n'))
                  .where((e) => e.trim().isNotEmpty)
                  .map((label) => label.replaceAll(' ', '_'))
                  .toList();

          _modelLoaded = _interpreterWrapper?.isModelLoaded ?? false;

          if (kDebugMode && _modelLoaded) {
            final inputTensorDetails = _interpreterWrapper!.getInputTensor(0);
            final outputTensorDetails = _interpreterWrapper!.getOutputTensor(0);
            print(
              '[DetectionService NATIVE] TFLite Model loaded via wrapper. Input: ${inputTensorDetails.shape}, Type: ${inputTensorDetails.type}',
            );
            print(
              '[DetectionService NATIVE] Output: ${outputTensorDetails.shape}, Type: ${outputTensorDetails.type}',
            );
            print(
              '[DetectionService NATIVE] Labels loaded: ${_labels?.length}',
            );
          } else if (kDebugMode && !_modelLoaded) {
            print(
              '[DetectionService NATIVE] TFLite Model FAILED to load via wrapper.',
            );
          }
        }
      }
    } catch (e, stackTrace) {
      _modelLoaded = false; // General catch-all ensures _modelLoaded is false
      if (kDebugMode) {
        print('[DetectionService] Error loading model: $e\n$stackTrace');
      }
      rethrow;
    } finally {
      _isLoadingModel = false;
      if (kDebugMode)
        print('[DetectionService] Finished model loading attempt.');
    }
  }

  Future<List<DetectionResult>> detect({
    required Uint8List imageBytes,
    required String plantId,
  }) async {
    if (kDebugMode) {
      print(
        '[DetectionService] detect called for plant $plantId. Image bytes length: ${imageBytes.length}',
      );
    }

    if (!_modelLoaded && !_isLoadingModel) {
      if (kDebugMode) print('[DetectionService] Dart _modelLoaded is false. Attempting to load model...');
      await loadModel(); // This will now throw if loading fails or state is inconsistent
    } else if (_isLoadingModel) {
      if (kDebugMode)
        print('[DetectionService] Model loading already in progress.');
      return Future.error(Exception('Model loading already in progress.'));
    }
    
    if (_labels == null) { // Labels check is also crucial
        throw Exception(
          "Detection failed: Labels are null. Ensure loadModel() succeeded and loaded labels.",
        );
    }

    if (!_modelLoaded) {
      // This check is crucial. loadModel() should set _modelLoaded or throw.
      // If we reach here and _modelLoaded is false, it means loadModel() completed without error 
      // but failed to set the flag (which shouldn't happen with the new logic) OR it was called while _isLoadingModel was true and that path didn't resolve _modelLoaded.
      // The new error in loadModel should prevent this path if loadModel was actually attempted and failed with inconsistency.
      if (kDebugMode) print('[DetectionService WEB] CRITICAL PRE-INFERENCE CHECK: _modelLoaded is false before attempting inference. This indicates a problem in loadModel logic.');
      throw Exception('TF.js model is not loaded. _modelLoaded is false prior to inference attempt.');
    }

    try {
      if (kIsWeb) {
        if (kDebugMode) print('[DetectionService WEB] Running TF.js inference. Dart _modelLoaded is true.');
        
        // Re-check window.loadedTfjsModel directly before calling runTFJSModelOnImageData
        var jsModelInstance = js_util.getProperty(js_util.globalThis, 'loadedTfjsModel');
        if (jsModelInstance == null) {
          if (kDebugMode) print('[DetectionService WEB] CRITICAL ERROR: Just before calling runTFJSModelOnImageData, window.loadedTfjsModel is NULL. Dart _modelLoaded: $_modelLoaded');
          throw Exception('TF.js model (window.loadedTfjsModel) became null just before inference, despite Dart thinking it was loaded. State inconsistency.');
        }
        if (kDebugMode) {
          String jsModelDartType = jsModelInstance.runtimeType.toString();
          String jsModelJsType = "unknown";
          try {
            if (js_util.hasProperty(jsModelInstance, 'constructor') && js_util.getProperty(jsModelInstance, 'constructor') != null) {
                jsModelJsType = js_util.getProperty(js_util.getProperty(jsModelInstance, 'constructor'), 'name')?.toString() ?? "null_constructor_name";
            } else {
              jsModelJsType = "no_constructor_property";
            }
          } catch (e) {
            jsModelJsType = "error_getting_js_type: $e";
          }
          print('[DetectionService WEB] Pre-inference check: window.loadedTfjsModel seems OK. Dart type: $jsModelDartType, JS type: $jsModelJsType');
        }

        final completer = Completer<List<DetectionResult>>();
        // Ensure imageBytes is Uint8List. Determine content type if possible, default to jpeg/png.
        final blob = html.Blob([imageBytes], 'image/jpeg'); 
        final imageUrl = html.Url.createObjectUrlFromBlob(blob);

        try {
          js.context.callMethod('runTFJSModelOnImageData', [
            imageUrl,
            js.allowInterop((dynamic errorMsg, dynamic classIndex, dynamic confidence) {
              html.Url.revokeObjectUrl(imageUrl); // Clean up ASAP

              if (errorMsg != null) {
                if (kDebugMode) print('[DetectionService WEB] TF.js inference error: $errorMsg');
                completer.completeError(Exception('TF.js inference error: $errorMsg'));
              } else {
                // Ensure classIndex and confidence are not null and are of expected types
                if (classIndex == null || confidence == null) {
                  if (kDebugMode) print('[DetectionService WEB] TF.js inference error: Received null for classIndex or confidence.');
                  completer.completeError(Exception('TF.js inference returned null for classIndex or confidence.'));
                  return;
                }

                int idx = classIndex as int;
                double conf = (confidence as num).toDouble();

                if (idx >= 0 && idx < _labels!.length) {
                  String diseaseName = _labels![idx];
                  if (kDebugMode) print('[DetectionService WEB] TF.js inference success: $diseaseName, Confidence: $conf');
                  completer.complete([
                    DetectionResult(
                      diseaseName: diseaseName.replaceAll('_', ' '), 
                      confidence: conf,
                      boundingBox: null, // TF.js model might not provide this
                    )
                  ]);
                } else {
                  if (kDebugMode) print('[DetectionService WEB] TF.js inference error: Invalid class index $idx (Labels count: ${_labels!.length})');
                  completer.completeError(Exception('TF.js inference returned invalid class index: $idx'));
                }
              }
            })
          ]);
        } catch (e) {
          html.Url.revokeObjectUrl(imageUrl); 
          if (kDebugMode) print('[DetectionService WEB] Synchronous error calling runTFJSModelOnImageData: $e');
          completer.completeError(Exception('Error calling TF.js function: $e'));
        }
        return completer.future;
      } else {
        if (_interpreterWrapper == null ||
            !_interpreterWrapper!.isModelLoaded) {
          throw Exception(
            "TFLite interpreter wrapper is not initialized or model not loaded for non-web platform.",
          );
        }
        if (kDebugMode)
          print(
            '[DetectionService NATIVE] Preprocessing for TFLite using wrapper...',
          );

        final img.Image? decodedImage = img.decodeImage(imageBytes);
        if (decodedImage == null) {
          throw Exception('Failed to decode image for TFLite.');
        }

        final inputTensor = _interpreterWrapper!.getInputTensor(0);
        final inputShape = inputTensor.shape;
        final inputType = inputTensor.type;
        final inputHeight = inputShape[1];
        final inputWidth = inputShape[2];

        final img.Image resizedImage = img.copyResize(
          decodedImage,
          width: inputWidth,
          height: inputHeight,
        );

        Object inputBuffer;
        if (inputType == TfliteDataTypeWrapper.uint8) {
          final Uint8List buffer = Uint8List(1 * inputHeight * inputWidth * 3);
          int bufferIndex = 0;
          for (int y = 0; y < inputHeight; y++) {
            for (int x = 0; x < inputWidth; x++) {
              final pixel = resizedImage.getPixel(x, y);
              buffer[bufferIndex++] = pixel.r.toInt();
              buffer[bufferIndex++] = pixel.g.toInt();
              buffer[bufferIndex++] = pixel.b.toInt();
            }
          }
          inputBuffer = buffer;
        } else if (inputType == TfliteDataTypeWrapper.float32) {
          final Float32List buffer = Float32List(
            1 * inputHeight * inputWidth * 3,
          );
          int bufferIndex = 0;
          for (int y = 0; y < inputHeight; y++) {
            for (int x = 0; x < inputWidth; x++) {
              final pixel = resizedImage.getPixel(x, y);
              buffer[bufferIndex++] = pixel.r.toInt() / 255.0;
              buffer[bufferIndex++] = pixel.g.toInt() / 255.0;
              buffer[bufferIndex++] = pixel.b.toInt() / 255.0;
            }
          }
          inputBuffer = buffer;
        } else {
          throw Exception(
            '[DetectionService NATIVE] Unsupported TFLite input tensor type via wrapper: $inputType',
          );
        }

        if (kDebugMode)
          print(
            '[DetectionService NATIVE] Running TFLite inference via wrapper...',
          );

        final outputTensor = _interpreterWrapper!.getOutputTensor(0);
        final outputShape = outputTensor.shape;
        final outputType = outputTensor.type;

        Object outputBuffer;
        if (outputType == TfliteDataTypeWrapper.float32) {
          outputBuffer = List.generate(
            outputShape[0],
            (_) => List.filled(outputShape[1], 0.0),
          );
        } else if (outputType == TfliteDataTypeWrapper.uint8) {
          outputBuffer = List.generate(
            outputShape[0],
            (_) => List.filled(outputShape[1], 0),
          );
        } else {
          throw Exception(
            '[DetectionService NATIVE] Unsupported TFLite output tensor type via wrapper: $outputType',
          );
        }

        _interpreterWrapper!.run(inputBuffer, outputBuffer);
        if (kDebugMode)
          print(
            '[DetectionService NATIVE] TFLite inference complete via wrapper.',
          );

        List<DetectionResult> detectionResults = [];
        if (outputBuffer is List && outputBuffer.isNotEmpty) {
          List<dynamic> scoresRaw = outputBuffer.first as List<dynamic>;
          List<double> probabilities;

          if (scoresRaw.first is double) {
            probabilities = scoresRaw.cast<double>();
          } else if (scoresRaw.first is int) {
            probabilities =
                scoresRaw.cast<int>().map((s) => s.toDouble() / 255.0).toList();
          } else {
            throw Exception(
              'Unexpected TFLite score type from wrapper output: ${scoresRaw.first.runtimeType}',
            );
          }

          if (kDebugMode)
            print(
              '[DetectionService NATIVE] Probabilities (from wrapper): $probabilities',
            );

          if (_labels == null || _labels!.isEmpty) {
            throw Exception("Labels are not loaded for TFLite model.");
          }

          double maxConfidence = 0.0;
          int maxIndex = -1;
          for (int i = 0; i < probabilities.length; i++) {
            if (probabilities[i] > maxConfidence) {
              maxConfidence = probabilities[i];
              maxIndex = i;
            }
          }

          if (maxIndex != -1 && maxIndex < _labels!.length) {
            detectionResults.add(
              DetectionResult(
                diseaseName: _labels![maxIndex].replaceAll('_', ' '),
                confidence: maxConfidence,
                boundingBox: null,
              ),
            );
          } else if (maxIndex != -1) {
            if (kDebugMode)
              print(
                "[DetectionService NATIVE] Warning: maxIndex $maxIndex out of bounds for labels (${_labels!.length}).",
              );
            detectionResults.add(
              DetectionResult(
                diseaseName: "Unknown (label index mismatch)",
                confidence: maxConfidence,
                boundingBox: null,
              ),
            );
          }
        }

        if (detectionResults.isEmpty) {
          if (kDebugMode)
            print(
              "[DetectionService NATIVE] No disease detected or low confidence.",
            );
          detectionResults.add(
            DetectionResult(
              diseaseName: "Healthy / Not Detected",
              confidence: 0.0,
              boundingBox: null,
            ),
          );
        }
        return detectionResults;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print(
          '[DetectionService] Error during detection for $plantId: $e\n$stackTrace',
        );
      }
      throw Exception('Detection failed: $e');
    } finally {
      if (kDebugMode)
        print('[DetectionService] Finished detection attempt for $plantId.');
    }
  }

  void dispose() {
    if (kDebugMode) print('[DetectionService] Disposing...');
    if (kIsWeb) {
      if (kDebugMode)
        print(
          '[DetectionService WEB] TF.js model resources disposed (simulated).',
        );
    } else {
      _interpreterWrapper?.close();
      _interpreterWrapper = null;
      if (kDebugMode)
        print(
          '[DetectionService NATIVE] TFLite interpreter (via wrapper) closed.',
        );
    }
    _modelLoaded = false;
    _labels = null;
    if (kDebugMode) print('[DetectionService] All resources disposed.');
  }

  // Map to store active analysis progress streams by plant ID
  final Map<String, StreamController<AnalysisProgress>> _progressStreams = {};

  /// Returns a stream of analysis progress for the given plant ID.
  /// The stream will provide updates about the analysis progress.
  Stream<AnalysisProgress>? getProgressStream(String plantId) {
    if (!_progressStreams.containsKey(plantId)) {
      if (kDebugMode)
        print(
          '[DetectionService] No active progress stream for plant ID: $plantId',
        );
      return null;
    }
    return _progressStreams[plantId]!.stream;
  }

  /// Starts tracking analysis progress for a plant.
  /// Returns a stream of analysis progress updates.
  Stream<AnalysisProgress> startProgressTracking(String plantId) {
    if (_progressStreams.containsKey(plantId)) {
      if (kDebugMode)
        print(
          '[DetectionService] Reusing existing progress stream for plant ID: $plantId',
        );
      return _progressStreams[plantId]!.stream;
    }

    final controller = StreamController<AnalysisProgress>.broadcast();
    _progressStreams[plantId] = controller;
    if (kDebugMode)
      print(
        '[DetectionService] Created new progress stream for plant ID: $plantId',
      );

    return controller.stream;
  }

  /// Updates the analysis progress for a specific plant.
  void updateProgress(String plantId, AnalysisProgress progress) {
    if (!_progressStreams.containsKey(plantId)) {
      if (kDebugMode)
        print(
          '[DetectionService] Cannot update progress: No active stream for plant ID: $plantId',
        );
      return;
    }

    _progressStreams[plantId]!.add(progress);
    if (kDebugMode)
      print(
        '[DetectionService] Updated progress for plant ID: $plantId - ${progress.stage} ${progress.progress}',
      );

    // Close the stream if analysis is complete or failed
    if (progress.stage == AnalysisStage.completed ||
        progress.stage == AnalysisStage.failed) {
      if (kDebugMode)
        print(
          '[DetectionService] Closing progress stream for plant ID: $plantId',
        );
      _progressStreams[plantId]!.close();
      _progressStreams.remove(plantId);
    }
  }
}

// The Uint8List.reshape and Float32List.reshape extensions are part of dart:typed_data
// and tflite_flutter also provides them. Since tflite_flutter is conditionally imported,
// for non-web, these extensions will be available. For web, this part of the code (TFLite block)
// is not executed. No explicit use of .reshape() is present in this file, so linter errors
// related to reshape should not occur.
