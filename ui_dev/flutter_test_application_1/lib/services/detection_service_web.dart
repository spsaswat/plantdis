// lib/services/detection_service_web.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';

// These imports are WEB-ONLY and are safe here.
import 'dart:js' as js;
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'detection_service.dart';

/// This function is called by the conditional import in detection_service.dart
/// when the platform is web.
DetectionService getDetectionService() => WebDetectionService();

/// Web-specific implementation of the DetectionService.
class WebDetectionService implements DetectionService {
  // --- Singleton Pattern Start ---
  static final WebDetectionService _instance = WebDetectionService._internal();

  factory WebDetectionService() {
    return _instance;
  }

  WebDetectionService._internal();
  // --- Singleton Pattern End ---

  // Web model (TF.js) paths
  static const String _webModelPath = 'assets/models/model.json';
  static const String _webLabelsPath = 'assets/models/labels_village.txt';

  List<String>? _labels;
  bool _modelLoaded = false;
  bool _isLoadingModel = false;

  @override
  bool get isModelLoaded => _modelLoaded;

  @override
  Future<void> loadModel() async {
    // This is the WEB-ONLY logic from your original file.
    if (_modelLoaded) {
      if (kDebugMode) print('[DetectionService WEB] Model already loaded.');
      return;
    }
    if (_isLoadingModel) {
      if (kDebugMode) print('[DetectionService WEB] Model loading already in progress.');
      return;
    }

    _isLoadingModel = true;
    if (kDebugMode) print('[DetectionService WEB] Starting to load model...');

    try {
      if (kDebugMode) print('[DetectionService WEB] Loading TF.js model and labels...');
      try {
        if (js.context['tf'] == null) throw Exception('TensorFlow.js library (tf) not found.');
        if (js.context['getLoadTFJSModelPromise'] == null) throw Exception('Required JS function getLoadTFJSModelPromise not found.');

        var loadModelPromise = js_util.callMethod(js_util.globalThis, 'getLoadTFJSModelPromise', [_webModelPath]);
        if (loadModelPromise == null) throw Exception('JS getLoadTFJSModelPromise did not return a Promise.');
        if (js_util.getProperty(loadModelPromise, 'then') == null) throw Exception('JS getLoadTFJSModelPromise did not return a valid Promise.');

        bool jsPromiseResolvedValue = await js_util.promiseToFuture<bool>(loadModelPromise);
        if (kDebugMode) print('[DetectionService WEB] JS promise resolved, returned: $jsPromiseResolvedValue');

        if (jsPromiseResolvedValue) {
          var jsModel = js_util.getProperty(js_util.globalThis, 'loadedTfjsModel');
          if (jsModel == null) {
            _modelLoaded = false;
            throw StateError('JS reported model success, but window.loadedTfjsModel is null.');
          } else {
            if (kDebugMode) print('[DetectionService WEB] window.loadedTfjsModel is accessible.');
            _modelLoaded = true;
          }
        } else {
          _modelLoaded = false;
          throw Exception('JS getLoadTFJSModelPromise did not return true.');
        }

        if (_modelLoaded) {
          final rawLabels = await rootBundle.loadString(_webLabelsPath);
          _labels = rawLabels.split(RegExp(r'\r?\n')).where((e) => e.trim().isNotEmpty).toList();
          if (kDebugMode) print('[DetectionService WEB] Labels loaded: ${_labels?.length}');
        }
      } catch (e, s) {
        _modelLoaded = false;
        if (kDebugMode) print('[DetectionService WEB] Error in web model loading block: $e\n$s');
        rethrow;
      }
    } catch (e, stackTrace) {
      _modelLoaded = false;
      if (kDebugMode) print('[DetectionService] Error loading model: $e\n$stackTrace');
      rethrow;
    } finally {
      _isLoadingModel = false;
      if (kDebugMode) print('[DetectionService WEB] Finished model loading attempt.');
    }
  }

  @override
  Future<List<DetectionResult>> detect({
    required Uint8List imageBytes,
    required String plantId,
  }) async {
    // This is the WEB-ONLY detection logic from your original file.
    if (!_modelLoaded) await loadModel();
    if (!_modelLoaded || _labels == null) throw Exception("Model or labels not loaded.");

    if (kDebugMode) print('[DetectionService WEB] Running TF.js inference.');
    var jsModelInstance = js_util.getProperty(js_util.globalThis, 'loadedTfjsModel');
    if (jsModelInstance == null) throw Exception('TF.js model became null before inference.');

    final completer = Completer<List<DetectionResult>>();
    final blob = html.Blob([imageBytes], 'image/jpeg');
    final imageUrl = html.Url.createObjectUrlFromBlob(blob);

    try {
      js.context.callMethod('runTFJSModelOnImageData', [
        imageUrl,
        js.allowInterop((dynamic errorMsg, dynamic classIndex, dynamic confidence) {
          html.Url.revokeObjectUrl(imageUrl);
          if (errorMsg != null) {
            completer.completeError(Exception('TF.js inference error: $errorMsg'));
          } else {
            int idx = classIndex as int;
            double conf = (confidence as num).toDouble();
            if (idx >= 0 && idx < _labels!.length) {
              String diseaseName = _labels![idx];
              completer.complete([
                DetectionResult(
                  diseaseName: diseaseName.replaceAll('_', ' '),
                  confidence: conf,
                  boundingBox: null,
                )
              ]);
            } else {
              completer.completeError(Exception('Invalid class index: $idx'));
            }
          }
        })
      ]);
    } catch (e) {
      html.Url.revokeObjectUrl(imageUrl);
      completer.completeError(Exception('Error calling TF.js function: $e'));
    }
    return completer.future;
  }

  @override
  void dispose() {
    _modelLoaded = false;
    _labels = null;
    if (kDebugMode) print('[DetectionService WEB] Disposed.');
  }

  // --- Progress Tracking Implementation ---
  final Map<String, StreamController<AnalysisProgress>> _progressStreams = {};

  @override
  Stream<AnalysisProgress>? getProgressStream(String plantId) {
    return _progressStreams[plantId]?.stream;
  }

  @override
  Stream<AnalysisProgress> startProgressTracking(String plantId) {
    if (_progressStreams.containsKey(plantId)) return _progressStreams[plantId]!.stream;
    final controller = StreamController<AnalysisProgress>.broadcast();
    _progressStreams[plantId] = controller;
    return controller.stream;
  }

  @override
  void updateProgress(String plantId, AnalysisProgress progress) {
    if (!_progressStreams.containsKey(plantId)) return;
    _progressStreams[plantId]!.add(progress);
    if (progress.stage == AnalysisStage.completed || progress.stage == AnalysisStage.failed) {
      _progressStreams[plantId]!.close();
      _progressStreams.remove(plantId);
    }
  }
}