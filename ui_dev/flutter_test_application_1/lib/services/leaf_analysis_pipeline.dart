import 'dart:async';
import 'dart:io' show Directory, File, Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test_application_1/data/disease_labels.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';
import 'package:flutter_test_application_1/services/inference_service.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/services/segmentation_service.dart'
    as seg_tfl;
import 'package:flutter_test_application_1/services/segmentation_service_onnx.dart'
    as seg_onnx;
import 'package:flutter_test_application_1/services/tflite_interop/tflite_wrapper.dart';
import 'package:flutter_test_application_1/utils/logger.dart';

/// Output of the plant-species classifier.
class SpeciesResult {
  const SpeciesResult({
    required this.species,
    this.confidence,
    this.probabilities = const [],
  });

  final String species;

  /// Null when the species was forced by the user rather than predicted.
  final double? confidence;
  final List<double> probabilities;
}

/// Everything one leaf image produced, including partial results.
///
/// A leaf can legitimately end up with a species but no detection (unsupported
/// plant with the generic model failing), so callers should check each field
/// rather than assuming all-or-nothing.
class LeafAnalysisOutcome {
  const LeafAnalysisOutcome({
    this.segmentationUrl,
    this.species,
    this.detection,
    this.error,
  });

  final String? segmentationUrl;
  final SpeciesResult? species;
  final DetectionResult? detection;
  final Object? error;

  bool get hasDetection => detection != null;
}

/// Headless version of the segment → species → disease pipeline.
///
/// `SegmentPage` runs these steps inline against its own widget state. Batch
/// processing needs the same steps without a widget, so the model work lives
/// here and `SegmentPage` delegates to it.
class LeafAnalysisPipeline {
  LeafAnalysisPipeline._();

  static const String segModelOnnx = 'onnx';
  static const String segModelTflite = 'tflite';

  static const String _segModelPrefKey = 'seg_default_model';
  static const String _onnxAssetPath = 'assets/models/leaf_mask_rcnn_v2.onnx';
  static const String _tfliteAssetPath = 'assets/models/best_float32.tflite';

  static const int _classifierInputSize = 224;

  static final PlantService _plantService = PlantService();
  static final LocalGuestService _localGuestService = LocalGuestService();

  /// The segmentation backend the user selected in Settings.
  static Future<String> defaultSegModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_segModelPrefKey) ?? segModelOnnx;
    } catch (_) {
      return segModelOnnx;
    }
  }

  static Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Writes [bytes] to a uniquely named temp file so the segmentation services
  /// (which take a [File]) can read it.
  static Future<File> writeTempImage(
    Uint8List bytes, {
    String prefix = 'leaf_input',
    String extension = 'png',
  }) async {
    final base = Directory.systemTemp.path;
    final sep = Platform.pathSeparator;
    final name = '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final path = base.endsWith(sep) ? '$base$name' : '$base$sep$name';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Runs the selected leaf-mask model. Returns `null` when the model asset is
  /// missing, so callers can fall back to the unsegmented image.
  static Future<File?> segment(
    File input, {
    required String segModel,
    File? outputFile,
  }) async {
    final modelPath =
        segModel == segModelOnnx ? _onnxAssetPath : _tfliteAssetPath;
    if (!await _assetExists(modelPath)) {
      logger.w('[LeafAnalysisPipeline] Segmentation model missing: $modelPath');
      return null;
    }

    if (segModel == segModelOnnx) {
      final svc = seg_onnx.OnnxSegmentationService();
      await svc.loadModel();
      return svc.segment(input, outputFile: outputFile);
    }
    final svc = seg_tfl.SegmentationService();
    await svc.loadModel();
    return svc.segment(input, outputFile: outputFile);
  }

  /// Builds the `[1, 224, 224, 3]` float input both classifiers expect.
  static List<Object> _classifierInput(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Failed to decode leaf image');
    }
    final resized = img.copyResize(
      decoded,
      width: _classifierInputSize,
      height: _classifierInputSize,
    );
    return [
      List.generate(
        _classifierInputSize,
        (y) => List.generate(_classifierInputSize, (x) {
          final p = resized.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        }),
      ),
    ];
  }

  static ({int index, double value}) _argmax(List<double> probs) {
    var maxIdx = 0;
    var maxVal = -1.0;
    for (var i = 0; i < probs.length; i++) {
      if (probs[i] > maxVal) {
        maxVal = probs[i];
        maxIdx = i;
      }
    }
    return (index: maxIdx, value: maxVal);
  }

  /// Identifies the plant species using `plants_detector.tflite`.
  static Future<SpeciesResult> classifySpecies(Uint8List bytes) async {
    final input = _classifierInput(bytes);
    final interpreter = TfliteInterpreter();
    await interpreter.loadModel(kSpeciesDetectorModelPath);
    final output = [List.filled(kSpeciesLabels.length, 0.0)];
    try {
      interpreter.run(input, output);
    } finally {
      interpreter.close();
    }

    final probs = (output[0] as List).cast<double>();
    final best = _argmax(probs);
    return SpeciesResult(
      species: kSpeciesLabels[best.index].toLowerCase().trim(),
      confidence: best.value,
      probabilities: probs,
    );
  }

  /// Runs the per-species disease detector, or the generic model when the
  /// species has no dedicated detector.
  static Future<DetectionResult?> detectDisease(
    Uint8List bytes, {
    required String species,
    required String plantId,
  }) async {
    final normalized = species.toLowerCase().trim();
    final modelPath = kSpeciesDiseaseModelPath[normalized];

    if (modelPath == null) {
      return InferenceService().analyzeImage(
        imageBytes: bytes,
        plantId: plantId,
        isSegmented: true,
      );
    }

    final input = _classifierInput(bytes);
    final interpreter = TfliteInterpreter();
    await interpreter.loadModel(modelPath);
    List<double> probs;
    try {
      // Output width varies per species, so read it from the model itself.
      final outShape = interpreter.getOutputTensor(0).shape;
      final outSize = outShape.length > 1 ? outShape[1] : 1;
      final output = [List.filled(outSize, 0.0)];
      interpreter.run(input, output);
      probs = (output[0] as List).cast<double>();
    } finally {
      interpreter.close();
    }

    final best = _argmax(probs);
    final labels = kDiseaseLabels[normalized];
    final diseaseName =
        (labels != null && best.index >= 0 && best.index < labels.length)
            ? labels[best.index]
            : (normalized.isNotEmpty ? normalized : 'Unknown plant');

    return DetectionResult(
      diseaseName: diseaseName,
      confidence: best.value,
      boundingBox: null,
    );
  }

  /// Stores a segmentation mask and returns the URL/URI to record.
  ///
  /// Guest mode writes into the Application Support mirror; Firebase mode
  /// uploads to Storage and updates `images/{imageId}.processedUrls.segmentation`.
  static Future<String?> persistSegmentation(
    File segmentedFile, {
    required String plantId,
    required String imageId,
  }) async {
    if (_localGuestService.isLocalGuestMode()) {
      return _localGuestService.persistSegmentationLocalUri(
        segmentedFile,
        plantId: plantId,
        imageId: imageId,
      );
    }
    try {
      final url = await _plantService.saveProcessedImage(
        segmentedFile,
        plantId,
        imageId,
        'segmentation',
      );
      await FirebaseFirestore.instance.collection('images').doc(imageId).update({
        'processedUrls.segmentation': url,
      });
      return url;
    } catch (e, st) {
      // A failed mask upload must not sink the whole analysis.
      logger.w('[LeafAnalysisPipeline] Segmentation upload failed: $e\n$st');
      return null;
    }
  }

  /// Segment → persist mask → classify species → detect disease.
  ///
  /// Never throws: any failure is returned in [LeafAnalysisOutcome.error]
  /// alongside whatever partial results were obtained, so a batch can record
  /// the failure for one leaf and carry on.
  ///
  /// Pass [skipSegmentation] when [imageBytes] is already a segmented leaf —
  /// for example a SAM-masked crop. The masking step is then bypassed entirely
  /// and the bytes go straight to the classifiers; [LeafAnalysisOutcome
  /// .segmentationUrl] stays null because the caller owns that image.
  static Future<LeafAnalysisOutcome> runFull({
    required Uint8List imageBytes,
    required String plantId,
    required String imageId,
    required String segModel,
    String? forcedSpecies,
    bool skipSegmentation = false,
  }) async {
    String? segmentationUrl;
    SpeciesResult? species;

    try {
      File? segmentedFile;
      if (!skipSegmentation) {
        final temp = await writeTempImage(imageBytes, prefix: 'leaf_seg_input');
        try {
          final maskTarget = await _localGuestService
              .segmentationOutputFileForWrite(
                plantId: plantId,
                imageId: imageId,
              );
          segmentedFile = await segment(
            temp,
            segModel: segModel,
            outputFile: maskTarget,
          );
        } catch (e, st) {
          // Fall through with the unsegmented crop rather than failing the leaf.
          logger.w('[LeafAnalysisPipeline] Segmentation failed: $e\n$st');
        } finally {
          unawaited(_deleteQuietly(temp));
        }

        if (segmentedFile != null) {
          segmentationUrl = await persistSegmentation(
            segmentedFile,
            plantId: plantId,
            imageId: imageId,
          );
        }
      }

      final analysisBytes =
          segmentedFile != null
              ? await segmentedFile.readAsBytes()
              : imageBytes;

      if (forcedSpecies != null && forcedSpecies.trim().isNotEmpty) {
        // Confidence stays null: it is not meaningful for a forced species.
        species = SpeciesResult(species: forcedSpecies.toLowerCase().trim());
      } else {
        species = await classifySpecies(analysisBytes);
      }

      final detection = await detectDisease(
        analysisBytes,
        species: species.species,
        plantId: plantId,
      );

      return LeafAnalysisOutcome(
        segmentationUrl: segmentationUrl,
        species: species,
        detection: detection,
      );
    } catch (e, st) {
      logger.e('[LeafAnalysisPipeline] runFull failed for $imageId: $e\n$st');
      return LeafAnalysisOutcome(
        segmentationUrl: segmentationUrl,
        species: species,
        error: e,
      );
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
