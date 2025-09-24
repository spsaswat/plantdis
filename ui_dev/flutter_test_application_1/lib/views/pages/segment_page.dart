import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/segment_hero_widget.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:flutter_test_application_1/models/plant_model.dart'; // Import PlantModel
import 'package:flutter_test_application_1/services/plant_service.dart'; // Import PlantService
import 'package:flutter_test_application_1/utils/ui_utils.dart'; // Import UIUtils
import 'dart:async'; // Import for TimeoutException
import 'package:flutter_test_application_1/utils/logger.dart';
import '../services/openrouter_service.dart';
import 'package:flutter_test_application_1/services/background_detection_service.dart'; // Import background detection service

import 'package:http/http.dart' as http; // Import for http requests
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:flutter_test_application_1/services/tflite_interop/tflite_wrapper.dart';
import 'package:flutter_test_application_1/services/segmentation_service.dart'
    as seg_tfl;
import 'package:flutter_test_application_1/services/segmentation_service_onnx.dart'
    as seg_onnx;
import 'package:flutter_test_application_1/services/inference_service.dart';
import 'package:flutter_test_application_1/models/detection_result.dart';

class SegmentPage extends StatefulWidget {
  const SegmentPage({
    super.key,
    required this.imgSrc,
    required this.id,
    required this.plantId,
  });

  final String imgSrc;
  final String id;
  final String plantId;

  @override
  State<SegmentPage> createState() => _SegmentPageState();
}

class _SegmentPageState extends State<SegmentPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance
  final PlantService _plantService =
      PlantService(); // Plant service for deletion

  // Background detection service
  final BackgroundDetectionService _backgroundDetectionService =
      BackgroundDetectionService();

  // State variables for background detection
  Map<String, dynamic>? _backgroundDetectionResult;
  bool _isBackgroundDetectionComplete = false;
  Future<Map<String, dynamic>>? _backgroundDetectionFuture;

  // State variables for segmentation and analysis
  bool _isAnalysisTriggered = false;

  static const double decisionThreshold = 0.7; // Leaf decision threshold

  // Segmentation model selector
  String _selectedSegModel = 'tflite'; // 'tflite' | 'onnx'
  bool _isBusy = false;
  String? _plantClass;
  double? _plantClassConf;
  bool _speciesLoading = false;
  bool _manualOverride = false;
  bool _speciesOverrideActive = false;
  String? _speciesOverrideSelection;
  bool _analysisConfirmed = false;
  final ScrollController _scrollController = ScrollController();
  String? _segPreviewUrl;
  String? _forcedSpecies; // if user overrides species selection, use this once

  // Cache species classifier labels and last probabilities for UI confidence display
  static const List<String> _speciesLabels = [
    'apple',
    'blueberry',
    'cherry',
    'corn',
    'grape',
    'orange',
    'peach',
    'pepper',
    'potato',
    'raspberry',
    'soybean',
    'squash',
    'strawberry',
    'tomato',
  ];
  List<double>? _lastSpeciesProbs;

  Future<File> _downloadToTemp(Uint8List bytes) async {
    final dir = Directory.systemTemp;
    final f = File(
      '${dir.path}/seg_input_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await f.writeAsBytes(bytes);
    return f;
  }

  Future<void> _runPlantSpeciesClassifier(Uint8List segBytes) async {
    // Load image and resize to classifier input (assume 224x224 float)
    final img.Image? decoded = img.decodeImage(segBytes);
    if (decoded == null) throw Exception('Failed to decode segmented image');
    final img.Image resized = img.copyResize(decoded, width: 224, height: 224);

    final input = [
      List.generate(
        224,
        (y) => List.generate(224, (x) {
          final p = resized.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        }),
      ),
    ];

    final interpreter = TfliteInterpreter();
    await interpreter.loadModel('assets/models/plants_detector.tflite');
    // Output shape [1, N]
    final output = [List.filled(14, 0.0)];
    interpreter.run(input, output);
    interpreter.close();

    final probs = (output[0] as List).cast<double>();
    int maxIdx = 0;
    double maxVal = -1;
    for (int i = 0; i < probs.length; i++) {
      if (probs[i] > maxVal) {
        maxVal = probs[i];
        maxIdx = i;
      }
    }
    const labels = _speciesLabels;
    if (mounted) {
      final species = labels[maxIdx].toLowerCase().trim();
      setState(() {
        _plantClass = species;
        _plantClassConf = maxVal;
        _lastSpeciesProbs = probs;
      });
    }
  }

  Future<DetectionResult?> _runDiseaseDetection(Uint8List bytes) async {
    // Choose model
    String modelPath;
    String species = (_forcedSpecies ?? _plantClass ?? '').toLowerCase().trim();
    if (species == 'corn') {
      modelPath = 'assets/models/corn_disease_detector.tflite';
    } else if (species == 'pepper') {
      modelPath = 'assets/models/pepper_disease_detector.tflite';
    } else if (species == 'grape') {
      modelPath = 'assets/models/grape_disease_detector.tflite';
    } else if (species == 'apple') {
      modelPath = 'assets/models/apple_mnv3_float32.tflite';
    } else if (species == 'potato') {
      modelPath = 'assets/models/potato_mnv3_float32.tflite';
    } else if (species == 'tomato') {
      modelPath = 'assets/models/tomato_mnv3_float32.tflite';
    } else {
      // fallback to original
      final res = await InferenceService().analyzeImage(
        imageBytes: bytes,
        plantId: widget.plantId,
        isSegmented: true,
      );
      // mark unknown species
      if (species.isNotEmpty &&
          species != 'corn' &&
          species != 'pepper' &&
          species != 'grape') {}
      return res;
    }

    // Run custom disease detector (assume [1,224,224,3] softmax)
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Failed to decode segmented image');
    final img.Image resized = img.copyResize(decoded, width: 224, height: 224);
    final input = [
      List.generate(
        224,
        (y) => List.generate(224, (x) {
          final p = resized.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        }),
      ),
    ];
    final interpreter = TfliteInterpreter();
    await interpreter.loadModel(modelPath);
    // read output size dynamically
    final outTensor = interpreter.getOutputTensor(0);
    final outShape = outTensor.shape;
    final outSize = outShape.length > 1 ? outShape[1] : 1;
    final output = [List.filled(outSize, 0.0)];
    interpreter.run(input, output);
    interpreter.close();
    final probs = (output[0] as List).cast<double>();
    int maxIdx = 0;
    double maxVal = -1;
    for (int i = 0; i < probs.length; i++) {
      if (probs[i] > maxVal) {
        maxVal = probs[i];
        maxIdx = i;
      }
    }
    String diseaseName;
    List<String>? labels;
    switch (species) {
      case 'corn':
        labels = const [
          'Corn___Cercospora_leaf_spot_Gray_leaf_spot',
          'Corn___Common_rust',
          'Corn___healthy',
          'Corn___Northern_Leaf_Blight',
        ];
        break;
      case 'pepper':
        labels = const ['Pepper_bacterial_spot', 'Pepper_healthy'];
        break;
      case 'grape':
        labels = const [
          'Grape___Black_rot',
          'Grape___Esca_(Black_Measles)',
          'Grape___healthy',
          'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
        ];
        break;
      case 'apple':
        labels = const [
          'Apple___Apple_scab',
          'Apple___Black_rot',
          'Apple___Cedar_apple_rust',
          'Apple___healthy',
        ];
        break;
      case 'potato':
        labels = const [
          'Potato___Early_blight',
          'Potato___Late_blight',
          'Potato___healthy',
        ];
        break;
      case 'tomato':
        labels = const [
          'Tomato___Bacterial_spot',
          'Tomato___Early_blight',
          'Tomato___Late_blight',
          'Tomato___Leaf_Mold',
          'Tomato___Septoria_leaf_spot',
          'Tomato___Spider_mites_Two_spotted_spider_mite',
          'Tomato___Target_Spot',
          'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
          'Tomato___Tomato_mosaic_virus',
          'Tomato___healthy',
        ];
        break;
      default:
        labels = null;
        break;
    }

    if (labels != null && maxIdx >= 0 && maxIdx < labels.length) {
      diseaseName = labels[maxIdx];
    } else {
      final String fallbackName =
          _plantClass ?? (species.isNotEmpty ? species : 'Unknown plant');
      diseaseName = fallbackName;
    }
    return DetectionResult(
      diseaseName: diseaseName,
      confidence: maxVal,
      boundingBox: null,
    );
  }

  Future<void> _kickSpeciesFromUrl(String url) async {
    if (_speciesLoading || _plantClass != null) return;
    _speciesLoading = true;
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        await _runPlantSpeciesClassifier(resp.bodyBytes);
      }
    } catch (e, st) {
      logger.w('[SegmentPage] Species classifier from URL failed: $e\n$st');
    } finally {
      _speciesLoading = false;
    }
  }

  Future<void> _resegmentAndDetectAndWrite() async {
    try {
      if (mounted) setState(() => _isBusy = true);

      // 1) Download original image
      final uri = Uri.parse(widget.imgSrc);
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw Exception('Failed to download image');
      }
      final temp = await _downloadToTemp(resp.bodyBytes);

      // 2) Segment locally with selected model
      File segmentedFile;
      if (_selectedSegModel == 'onnx') {
        final svc = seg_onnx.OnnxSegmentationService();
        await svc.loadModel();
        segmentedFile = await svc.segment(temp);
      } else {
        final svc = seg_tfl.SegmentationService();
        await svc.loadModel();
        segmentedFile = await svc.segment(temp);
      }

      // 3) Upload segmented image (optional but populates segmentationUrl)
      String? segmentationUrl;
      try {
        segmentationUrl = await _plantService.saveProcessedImage(
          segmentedFile,
          widget.plantId,
          widget.id,
          'segmentation',
        );
        await _firestore.collection('images').doc(widget.id).update({
          'processedUrls.segmentation': segmentationUrl,
        });
      } catch (_) {
        // Continue even if upload fails
      }

      // 4) Run detection on segmented image bytes (local inference)
      final segBytes = await segmentedFile.readAsBytes();

      // 4a) Determine plant species
      if (_forcedSpecies != null) {
        if (mounted) {
          setState(() {
            _plantClass = _forcedSpecies;
            _plantClassConf = null; // confidence not applicable when forced
          });
        }
      } else {
        await _runPlantSpeciesClassifier(segBytes);
      }

      // 4b) Choose disease model based on species
      final Uint8List bytesForDisease = segBytes;
      final detection = await _runDiseaseDetection(bytesForDisease);
      final result = detection;

      // 5) Write back analysisResults to plants/<plantId>
      if (result != null) {
        final analysisData = {
          'detectedDisease': result.diseaseName,
          'confidence': result.confidence,
          'detectionTimestamp': DateTime.now().toIso8601String(),
          if (segmentationUrl != null) 'segmentationUrl': segmentationUrl,
          if (_plantClass != null) 'plantSpecies': _plantClass,
          if (_plantClassConf != null)
            'plantSpeciesConfidence': _plantClassConf,
        };
        await _firestore.collection('plants').doc(widget.plantId).update({
          'status': 'completed',
          'analysisResults': analysisData,
          'analysisError': FieldValue.delete(),
        });
      } else {
        await _firestore.collection('plants').doc(widget.plantId).update({
          'status': 'error',
          'analysisError': 'Local analysis returned no result',
        });
      }
    } catch (e, st) {
      logger.e('[SegmentPage] Re-segment/detect failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Re-run failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _segmentAndClassifyOnly() async {
    try {
      if (mounted) {
        setState(() {
          _isBusy = true;
        });
      }

      // 1) Download original image
      final uri = Uri.parse(widget.imgSrc);
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw Exception('Failed to download image');
      }
      final temp = await _downloadToTemp(resp.bodyBytes);

      // 2) Segment locally with selected model
      File segmentedFile;
      if (_selectedSegModel == 'onnx') {
        final svc = seg_onnx.OnnxSegmentationService();
        await svc.loadModel();
        segmentedFile = await svc.segment(temp);
      } else {
        final svc = seg_tfl.SegmentationService();
        await svc.loadModel();
        segmentedFile = await svc.segment(temp);
      }

      // 3) Upload segmented image (populate segmentationUrl)
      String? segmentationUrl;
      try {
        segmentationUrl = await _plantService.saveProcessedImage(
          segmentedFile,
          widget.plantId,
          widget.id,
          'segmentation',
        );
        await _firestore.collection('images').doc(widget.id).update({
          'processedUrls.segmentation': segmentationUrl,
        });
      } catch (_) {}

      // 4) Run plant species classifier for UI display
      final segBytes = await segmentedFile.readAsBytes();
      await _runPlantSpeciesClassifier(segBytes);

      // 5) Persist minimal analysisResults (segmentationUrl and optional species)
      final Map<String, Object?> updates = {
        if (segmentationUrl != null)
          'analysisResults.segmentationUrl': segmentationUrl,
        'analysisResults.detectionTimestamp': DateTime.now().toIso8601String(),
        if (_plantClass != null) 'analysisResults.plantSpecies': _plantClass,
        if (_plantClassConf != null)
          'analysisResults.plantSpeciesConfidence': _plantClassConf,
      };
      if (updates.isNotEmpty) {
        await _firestore
            .collection('plants')
            .doc(widget.plantId)
            .update(updates);
      }
      if (mounted)
        setState(() {
          _segPreviewUrl = segmentationUrl;
        });
    } catch (e, st) {
      logger.e('[SegmentPage] Segmentation-only failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Segmentation failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _runLocalSegmentationAndRetrigger() async {
    await _resegmentAndDetectAndWrite();
  }

  // Helper function to format the timestamp
  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime dateTime = DateTime.parse(timestamp);
      // Example format: May 1, 2025 7:01 PM
      return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
    } catch (e) {
      return timestamp; // Return original if parsing fails
    }
  }

  // Helper function to format confidence
  String _formatConfidence(dynamic confidence) {
    if (confidence == null) return 'N/A';
    if (confidence is double) {
      return '${(confidence * 100).toStringAsFixed(1)}%';
    }
    if (confidence is int) {
      return '${(confidence * 100)}%';
    }
    return confidence.toString(); // Fallback
  }

  /// Detect if image contains plant leaves using background detection model
  Future<Map<String, dynamic>> _detectBackgroundAndLeaves() async {
    try {
      // Validate image URL
      if (widget.imgSrc.isEmpty) {
        throw Exception('Image source URL is empty');
      }

      // Download image from URL to get bytes with timeout
      final response = await http
          .get(Uri.parse(widget.imgSrc))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Image download timeout after 30 seconds');
            },
          );

      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }

      final imageBytes = response.bodyBytes;

      // Validate image bytes
      if (imageBytes.isEmpty) {
        throw Exception('Downloaded image is empty');
      }

      // Load user confidence threshold
      final prefs = await SharedPreferences.getInstance();
      final int uiThreshold = prefs.getInt('seg_conf_threshold') ?? 80;
      final double threshold = (uiThreshold.clamp(0, 100)) / 100.0;
      // Load default segmentation model
      _selectedSegModel =
          prefs.getString('seg_default_model') ?? _selectedSegModel;

      // Run background detection
      final backgroundResult = await _backgroundDetectionService.detectLeaves(
        imageBytes: imageBytes,
        confidenceThreshold: threshold,
      );

      if (kDebugMode) {
        logger.i(
          '[SegmentPage] Background detection result: $backgroundResult',
        );
      }

      // Store result in state only if widget is still mounted
      if (mounted) {
        setState(() {
          _backgroundDetectionResult = backgroundResult;
          _isBackgroundDetectionComplete = true;
        });
      }

      return backgroundResult;
    } catch (e, stackTrace) {
      logger.e('[SegmentPage] Error in background detection: $e\n$stackTrace');
      // Return default result indicating no leaves detected
      final errorResult = {
        'hasLeaves': false,
        'leafProbability': 0.0,
        'backgroundProbability': 1.0,
        'error': e.toString(),
        'method': 'error_fallback',
      };

      // Store result in state only if widget is still mounted
      if (mounted) {
        setState(() {
          _backgroundDetectionResult = errorResult;
          _isBackgroundDetectionComplete = true;
        });
      }

      return errorResult;
    }
  }

  // removed unused _triggerPlantAnalysis

  /// Format method name for display
  String _formatMethodName(String method) {
    switch (method) {
      case 'tflite_model':
        return 'TFLite Model';
      case 'fallback_heuristic':
      case 'fallback_heuristic_hardcoded':
        return 'Fallback Heuristic';
      case 'fallback_safe_default':
      case 'fallback_safe_default_hardcoded':
        return 'Safe Default';
      case 'error_fallback':
      case 'fallback_error':
        return 'Error Fallback';
      default:
        return method.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define a low confidence threshold
    const double lowConfidenceThreshold = 0.1; // 10%

    return Scaffold(
      appBar: const AppbarWidget(),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream:
                _firestore.collection('plants').doc(widget.plantId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('Loading plant data...'),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                logger.e(
                  'Error in StreamBuilder for plant ${widget.plantId}: ${snapshot.error}',
                );
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 20),
                      Text('Error loading plant data: ${snapshot.error}'),
                      // Optional: Add a retry button if appropriate
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.info_outline, // Changed icon
                          size: 60,
                          color: Colors.blueGrey, // Changed color
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          'Plant Data Unavailable', // Changed title
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'This plant data (ID: ${widget.plantId}) cannot be displayed. It might have been deleted or is still processing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400], // Adjusted color
                            height: 1.4, // Added line height
                          ),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Go Back'),
                          style: ElevatedButton.styleFrom(
                            // Use primary color for button background
                            foregroundColor: Colors.white, // White text
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Data is available, parse it
              final docData = snapshot.data!.data()!;
              PlantModel plant = PlantModel.fromMap(docData);
              Map<String, dynamic>? analysisResults = plant.analysisResults;
              String status = plant.status;
              // Read analysisError directly from the document data
              String? analysisErrorMsg = docData['analysisError'] as String?;

              // Determine display state based on results and confidence
              bool hasResults =
                  analysisResults != null && analysisResults.isNotEmpty;
              double diseaseConfidence = 0.0;
              if (hasResults && analysisResults['confidence'] != null) {
                diseaseConfidence =
                    (analysisResults['confidence'] as num).toDouble();
              }
              bool isLowConfidence =
                  hasResults && diseaseConfidence < lowConfidenceThreshold;
              String detectedDisease = 'N/A';
              if (hasResults) {
                detectedDisease =
                    analysisResults['detectedDisease']?.toString() ?? 'N/A';
              }

              // Format the displayed disease name to show spaces instead of underscores
              String displayDiseaseName = UIUtils.formatDiseaseName(
                detectedDisease,
              );

              String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

              Widget probBar({
                required String label,
                required double value,
                required Color color,
              }) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 12)),
                        Text(
                          pct(value),
                          style: TextStyle(fontSize: 12, color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: value.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                );
              }

              Widget buildAsteriskFootnotes() {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Notes', style: KTextStyle.titleTealText),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '* ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: Text(
                                  'Disease detection: may be inaccurate due to look-alike symptoms, image quality, or diseases outside the training set. Confirm before acting.',
                                  style: KTextStyle.descriptionText.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '**  ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: Text(
                                  'AI-generated suggestion: general guidance only. Always verify with trusted sources or a qualified agronomist/plant pathologist.',
                                  style: KTextStyle.descriptionText.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Disclaimer: Results are provided “as is.” APPN and contributors are not liable for any loss or damage arising from use of these outputs.',
                            style: KTextStyle.descriptionText.copyWith(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Debug prints inside StreamBuilder
              // print('[SegmentPage StreamBuilder] plantId: ${widget.plantId}');
              // print('[SegmentPage StreamBuilder] status: $status');
              // print('[SegmentPage StreamBuilder] analysisResults: $analysisResults');
              // print('[SegmentPage StreamBuilder] hasResults: $hasResults');
              // print('[SegmentPage StreamBuilder] diseaseConfidence: $diseaseConfidence');
              // print('[SegmentPage StreamBuilder] detectedDisease: $detectedDisease');

              return Center(
                heightFactor: 1,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return FractionallySizedBox(
                          widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                          child: Column(
                            spacing: 10.0,
                            children: [
                              SegmentHero(imgSrc: widget.imgSrc, id: widget.id),

                              // Background Detection Result
                              Padding(
                                padding: const EdgeInsets.only(top: 15.0),
                                child: FutureBuilder<Map<String, dynamic>>(
                                  future:
                                      _backgroundDetectionFuture ??=
                                          _detectBackgroundAndLeaves().catchError((
                                            error,
                                          ) {
                                            // Handle errors gracefully to prevent crashes
                                            logger.e(
                                              '[SegmentPage] Background detection failed: $error',
                                            );
                                            return {
                                              'hasLeaves': false,
                                              'leafProbability': 0.0,
                                              'backgroundProbability': 1.0,
                                              'error': error.toString(),
                                              'method': 'error_fallback',
                                            };
                                          }),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Card(
                                        child: Padding(
                                          padding: EdgeInsets.all(15.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Center(
                                                child: Text(
                                                  "Background Detection",
                                                  style:
                                                      KTextStyle.titleTealText,
                                                ),
                                              ),
                                              SizedBox(height: 15),
                                              Center(
                                                child: Column(
                                                  children: [
                                                    CircularProgressIndicator(),
                                                    SizedBox(height: 10),
                                                    Text(
                                                      'Detecting plant leaves...',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    } else if (snapshot.hasError) {
                                      return Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Center(
                                                child: Text(
                                                  "Background Detection",
                                                  style:
                                                      KTextStyle.titleTealText,
                                                ),
                                              ),
                                              const SizedBox(height: 15),
                                              Center(
                                                child: Column(
                                                  children: [
                                                    const Icon(
                                                      Icons.error_outline,
                                                      color: Colors.red,
                                                      size: 32,
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      'Detection failed: ${snapshot.error}',
                                                      style: const TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    } else {
                                      final result = snapshot.data!;
                                      final hasLeaves =
                                          result['hasLeaves'] as bool? ?? false;
                                      final backgroundProbability =
                                          (result['backgroundProbability']
                                                  as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      final method =
                                          result['method'] as String? ??
                                          'unknown';

                                      final double leafProb =
                                          (result['leafProbability'] as num?)
                                              ?.toDouble() ??
                                          (1.0 - backgroundProbability);

                                      return Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Center(
                                                child: Text(
                                                  "Background Detection",
                                                  style:
                                                      KTextStyle.titleTealText,
                                                ),
                                              ),
                                              const SizedBox(height: 15),
                                              ListTile(
                                                leading: Icon(
                                                  hasLeaves
                                                      ? Icons.eco
                                                      : Icons
                                                          .image_not_supported,
                                                  color:
                                                      hasLeaves
                                                          ? Colors.green
                                                          : Colors.grey,
                                                  size: 32,
                                                ),
                                                title: Text(
                                                  hasLeaves
                                                      ? 'Plant Leaves Detected'
                                                      : 'No Plant Leaves',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        hasLeaves
                                                            ? Colors.green
                                                            : Colors.grey,
                                                  ),
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Method: ${_formatMethodName(method)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              probBar(
                                                label: 'Leaf Probability',
                                                value: leafProb,
                                                color: Colors.green.shade700,
                                              ),
                                              const SizedBox(height: 10),
                                              probBar(
                                                label: 'Background Probability',
                                                value: backgroundProbability,
                                                color: Colors.blueGrey.shade700,
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.flag_circle_outlined,
                                                    size: 16,
                                                    color: Colors.teal,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Decision threshold: ${pct(decisionThreshold)} (Leaf)',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (method.contains('fallback') &&
                                                  result['greenRatio'] !=
                                                      null &&
                                                  result['brightRatio'] !=
                                                      null) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Heuristic details – Green: ${pct((result['greenRatio'] as num).toDouble())} • Bright: ${pct((result['brightRatio'] as num).toDouble())}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                if (result['note'] != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 2.0,
                                                        ),
                                                    child: Text(
                                                      result['note'].toString(),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Colors
                                                                .orange
                                                                .shade700,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                              if (hasLeaves)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 10.0,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10.0,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.green.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8.0,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            Colors
                                                                .green
                                                                .shade200,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .check_circle_outline,
                                                          color:
                                                              Colors
                                                                  .green
                                                                  .shade600,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            'Image contains plant leaves. Proceeding with segmentation and disease detection.',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors
                                                                      .green
                                                                      .shade700,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              else
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 10.0,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10.0,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.orange.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8.0,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            Colors
                                                                .orange
                                                                .shade200,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .warning_amber_outlined,
                                                          color:
                                                              Colors
                                                                  .orange
                                                                  .shade600,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            'No plant leaves detected. Please upload an image that clearly shows plant leaves.',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors
                                                                      .orange
                                                                      .shade700,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),

                              // Manually Overide button (fixed position under Background Detection)
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Center(
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _isBusy
                                            ? null
                                            : () async {
                                              setState(() {
                                                _manualOverride = true;
                                              });
                                              // Run segmentation first to show the result
                                              await _segmentAndClassifyOnly();
                                            },
                                    icon: const Icon(Icons.flash_on),
                                    label: const Text('Manually Overide'),
                                  ),
                                ),
                              ),

                              // Check if background detection indicates no leaves (high background probability = no leaves)
                              // Only show subsequent content if leaves are detected
                              if (_isBackgroundDetectionComplete &&
                                  _backgroundDetectionResult != null &&
                                  _backgroundDetectionResult!['error'] ==
                                      null) ...[
                                // Check if background detection shows high probability for background (no leaves)
                                // Note: backgroundProbability = probability of being background without leaves
                                if ((((_backgroundDetectionResult!['backgroundProbability']
                                                        as num?)
                                                    ?.toDouble() ??
                                                0.0) >=
                                            (1 - decisionThreshold) ||
                                        !(_backgroundDetectionResult!['hasLeaves']
                                                as bool? ??
                                            true)) &&
                                    !_manualOverride) ...[
                                  // Show message when background is detected with high confidence
                                  Padding(
                                    padding: const EdgeInsets.only(top: 15.0),
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.image_not_supported,
                                              size: 48,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(height: 12),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'No Plant Leaves Detected',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Please upload a photo that clearly shows plant leaves.',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 16),
                                            Container(
                                              padding: const EdgeInsets.all(
                                                12.0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                                border: Border.all(
                                                  color: Colors.orange.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.info_outline,
                                                    color:
                                                        Colors.orange.shade600,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Background probability is ${(((_backgroundDetectionResult!['backgroundProbability'] as num?)?.toDouble() ?? 0.0) * 100).toStringAsFixed(1)}%. This image appears to contain only background without plant leaves.',
                                                      style: TextStyle(
                                                        color:
                                                            Colors
                                                                .orange
                                                                .shade700,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                ...[
                                  // continue with the rest content
                                  // Show subsequent content only if leaves are detected
                                  // Auto-trigger analysis if not already triggered and plant is not processing/completed
                                  if (!_isAnalysisTriggered &&
                                      status != 'processing' &&
                                      status != 'analyzing' &&
                                      status != 'completed')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 15.0),
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            _isBusy
                                                ? null
                                                : () async {
                                                  await _segmentAndClassifyOnly();
                                                },
                                        icon: const Icon(Icons.auto_fix_high),
                                        label: const Text(
                                          'Run segmentation (preview)',
                                        ),
                                      ),
                                    ),

                                  // Check for segmentation result in analysisResults
                                  // Only show if leaves are detected OR manual override is active
                                  if (((hasResults &&
                                              analysisResults['segmentationUrl'] !=
                                                  null) ||
                                          _segPreviewUrl != null) &&
                                      ((_backgroundDetectionResult != null &&
                                              (_backgroundDetectionResult!['hasLeaves']
                                                      as bool? ??
                                                  false)) ||
                                          _manualOverride))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 15.0),
                                      child: Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Kick species classification on first render when URL is present
                                              Builder(
                                                builder: (context) {
                                                  final String? segUrl =
                                                      _segPreviewUrl ??
                                                      (analysisResults?['segmentationUrl']
                                                          as String?);
                                                  if (_plantClass == null &&
                                                      !_speciesLoading) {
                                                    // fire-and-forget
                                                    if (segUrl != null) {
                                                      _kickSpeciesFromUrl(
                                                        segUrl,
                                                      );
                                                    }
                                                  }
                                                  return const SizedBox.shrink();
                                                },
                                              ),
                                              const Center(
                                                child: Text(
                                                  "Segmentation Result",
                                                  style:
                                                      KTextStyle.titleTealText,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  DropdownButton<String>(
                                                    value: _selectedSegModel,
                                                    items: const [
                                                      DropdownMenuItem(
                                                        value: 'tflite',
                                                        child: Text('TFLite'),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: 'onnx',
                                                        child: Text('ONNX'),
                                                      ),
                                                    ],
                                                    onChanged: (v) async {
                                                      if (v == null) return;
                                                      setState(
                                                        () =>
                                                            _selectedSegModel =
                                                                v,
                                                      );
                                                      await _runLocalSegmentationAndRetrigger();
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 15),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(5.0),
                                                child: Image.network(
                                                  (_segPreviewUrl ??
                                                          (analysisResults?['segmentationUrl']
                                                              as String?)) ??
                                                      '',
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) {
                                                    return Container(
                                                      width: double.infinity,
                                                      height: 200,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade200,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              5.0,
                                                            ),
                                                      ),
                                                      child: const Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 48,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                            SizedBox(height: 8),
                                                            Text(
                                                              'Failed to load image',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  loadingBuilder: (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress ==
                                                        null) {
                                                      return child;
                                                    }
                                                    return Container(
                                                      width: double.infinity,
                                                      height: 200,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade100,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              5.0,
                                                            ),
                                                      ),
                                                      child: const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              // Species confirmation controls (English)
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Is the detected plant correct?',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                        ),
                                                      ),
                                                      Builder(
                                                        builder: (context) {
                                                          String text;
                                                          if (_plantClass ==
                                                              null) {
                                                            text = 'Plant: N/A';
                                                          } else {
                                                            double? conf =
                                                                _plantClassConf;
                                                            if (conf == null &&
                                                                _lastSpeciesProbs !=
                                                                    null) {
                                                              final idx =
                                                                  _speciesLabels
                                                                      .indexOf(
                                                                        _plantClass!,
                                                                      );
                                                              if (idx >= 0 &&
                                                                  idx <
                                                                      _lastSpeciesProbs!
                                                                          .length) {
                                                                conf =
                                                                    _lastSpeciesProbs![idx];
                                                              }
                                                            }
                                                            final confStr =
                                                                conf != null
                                                                    ? (100 *
                                                                                conf)
                                                                            .toStringAsFixed(
                                                                              1,
                                                                            ) +
                                                                        '%'
                                                                    : 'N/A';
                                                            text =
                                                                'Plant: ${_plantClass!}  ($confStr)';
                                                          }
                                                          return Text(
                                                            text,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      Colors
                                                                          .grey,
                                                                ),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      TextButton(
                                                        onPressed:
                                                            _isBusy
                                                                ? null
                                                                : () async {
                                                                  setState(() {
                                                                    _analysisConfirmed =
                                                                        true;
                                                                    _forcedSpecies =
                                                                        _plantClass; // honor current species
                                                                  });
                                                                  await _runLocalSegmentationAndRetrigger();
                                                                  if (mounted) {
                                                                    setState(() {
                                                                      _forcedSpecies =
                                                                          null; // clear after one run
                                                                    });
                                                                  }
                                                                },
                                                        child: const Text(
                                                          'Yes, continue',
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      OutlinedButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            _speciesOverrideActive =
                                                                true;
                                                          });
                                                          // keep scroll position after expanding selector
                                                          WidgetsBinding
                                                              .instance
                                                              .addPostFrameCallback((
                                                                _,
                                                              ) {
                                                                if (!mounted)
                                                                  return;
                                                                if (_scrollController
                                                                    .hasClients) {
                                                                  _scrollController.jumpTo(
                                                                    _scrollController
                                                                        .position
                                                                        .pixels,
                                                                  );
                                                                }
                                                              });
                                                        },
                                                        child: const Text(
                                                          "No, I'll choose",
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (_speciesOverrideActive) ...[
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: DropdownButtonFormField<
                                                            String
                                                          >(
                                                            value:
                                                                _speciesOverrideSelection,
                                                            decoration: const InputDecoration(
                                                              isDense: true,
                                                              border:
                                                                  OutlineInputBorder(),
                                                              labelText:
                                                                  'Select a plant',
                                                            ),
                                                            items: const [
                                                              DropdownMenuItem(
                                                                value: 'corn',
                                                                child: Text(
                                                                  'corn',
                                                                ),
                                                              ),
                                                              DropdownMenuItem(
                                                                value: 'apple',
                                                                child: Text(
                                                                  'apple',
                                                                ),
                                                              ),
                                                              DropdownMenuItem(
                                                                value: 'grape',
                                                                child: Text(
                                                                  'grape',
                                                                ),
                                                              ),
                                                              DropdownMenuItem(
                                                                value: 'pepper',
                                                                child: Text(
                                                                  'pepper',
                                                                ),
                                                              ),
                                                              DropdownMenuItem(
                                                                value: 'potato',
                                                                child: Text(
                                                                  'potato',
                                                                ),
                                                              ),
                                                              DropdownMenuItem(
                                                                value: 'tomato',
                                                                child: Text(
                                                                  'tomato',
                                                                ),
                                                              ),
                                                            ],
                                                            onChanged: (v) {
                                                              setState(() {
                                                                _speciesOverrideSelection =
                                                                    v;
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        ElevatedButton(
                                                          onPressed:
                                                              (_isBusy ||
                                                                      _speciesOverrideSelection ==
                                                                          null)
                                                                  ? null
                                                                  : () async {
                                                                    setState(() {
                                                                      _plantClass =
                                                                          _speciesOverrideSelection;
                                                                      _forcedSpecies =
                                                                          _speciesOverrideSelection;
                                                                      _speciesOverrideActive =
                                                                          false;
                                                                      _analysisConfirmed =
                                                                          true;
                                                                    });
                                                                    await _runLocalSegmentationAndRetrigger();
                                                                    // clear forced species after one run
                                                                    if (mounted) {
                                                                      setState(() {
                                                                        _forcedSpecies =
                                                                            null;
                                                                      });
                                                                    }
                                                                  },
                                                          child: const Text(
                                                            'Run with selection',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  if (_analysisConfirmed)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10.0,
                                      ),
                                      child: Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            spacing: 5.0,
                                            children: [
                                              const Center(
                                                child: Text(
                                                  "Analysis Results",
                                                  style:
                                                      KTextStyle.titleTealText,
                                                ),
                                              ),
                                              if (_plantClass != null &&
                                                  _plantClass != 'corn' &&
                                                  _plantClass != 'pepper' &&
                                                  _plantClass != 'grape' &&
                                                  _plantClass != 'apple' &&
                                                  _plantClass != 'potato' &&
                                                  _plantClass != 'tomato')
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    top: 4.0,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'This plant is not recognized by our specialized models. Accuracy is for reference only.',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                              const SizedBox(height: 10),
                                              // Handle different statuses
                                              if (status == 'processing' ||
                                                  status == 'analyzing')
                                                ListTile(
                                                  leading:
                                                      const CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                  title: const Text(
                                                    'Analysis in progress...',
                                                  ),
                                                  subtitle: const Text(
                                                    'Results will appear here shortly.',
                                                  ),
                                                  trailing: IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed:
                                                        () => _confirmDelete(
                                                          context,
                                                        ),
                                                    tooltip: 'Cancel analysis',
                                                  ),
                                                )
                                              else if (status == 'error')
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.error_outline,
                                                    color: Colors.red,
                                                  ),
                                                  title: const Text(
                                                    'Analysis Failed',
                                                  ),
                                                  subtitle: Text(
                                                    analysisErrorMsg ??
                                                        'An unknown error occurred.',
                                                  ),
                                                )
                                              // Display results if completed
                                              else if (status ==
                                                  'completed') ...[
                                                if (hasResults) ...[
                                                  if (detectedDisease ==
                                                      'No disease detected')
                                                    const ListTile(
                                                      leading: Icon(
                                                        Icons
                                                            .check_circle_outline,
                                                        color: Colors.green,
                                                      ),
                                                      title: Text(
                                                        'Analysis Completed',
                                                      ),
                                                      subtitle: Text(
                                                        'No disease detected above the confidence threshold.',
                                                      ),
                                                    )
                                                  else if (isLowConfidence)
                                                    _buildLowConfidenceInfo(
                                                      displayDiseaseName,
                                                      diseaseConfidence,
                                                    )
                                                  else
                                                    _buildStandardResults(
                                                      displayDiseaseName,
                                                      diseaseConfidence,
                                                    ),
                                                  // Always show detection time if available
                                                  _buildResultTile(
                                                    icon: Icons.timer_outlined,
                                                    label: 'Detection Time',
                                                    value: _formatTimestamp(
                                                      analysisResults['detectionTimestamp']
                                                          ?.toString(),
                                                    ),
                                                  ),

                                                  // Add delete button
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 16.0,
                                                        ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        TextButton.icon(
                                                          style:
                                                              TextButton.styleFrom(
                                                                foregroundColor:
                                                                    Colors.red,
                                                              ),
                                                          icon: const Icon(
                                                            Icons
                                                                .delete_outline,
                                                          ),
                                                          label: const Text(
                                                            'Delete Result',
                                                          ),
                                                          onPressed:
                                                              () =>
                                                                  _confirmDelete(
                                                                    context,
                                                                  ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ] else
                                                  const ListTile(
                                                    leading: Icon(
                                                      Icons.info_outline,
                                                      color: Colors.grey,
                                                    ),
                                                    title: Text(
                                                      "No analysis results available.",
                                                    ),
                                                    subtitle: Text(
                                                      "The analysis completed, but no specific results were found.",
                                                    ),
                                                  ),
                                              ] else // Handle other statuses like 'pending' or unknown
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.hourglass_empty,
                                                    color: Colors.grey,
                                                  ),
                                                  title: const Text(
                                                    'Analysis Pending',
                                                  ),
                                                  subtitle: Text(
                                                    'Status: $status',
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_analysisConfirmed)
                                    FutureBuilder<String>(
                                      future: _generateSuggestion(
                                        detectedDisease,
                                        diseaseConfidence,
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return _buildAiSuggestionBox(
                                            'Generating AI suggestion...',
                                          );
                                        } else if (snapshot.hasError) {
                                          return _buildAiSuggestionBox(
                                            'Failed to generate suggestion.',
                                          );
                                        } else {
                                          return _buildAiSuggestionBox(
                                            snapshot.data ??
                                                'No suggestion available.',
                                          );
                                        }
                                      },
                                    ),
                                  if (_analysisConfirmed)
                                    buildAsteriskFootnotes(),
                                ],
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          if (_isBusy)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget to display standard, confident results
  Widget _buildStandardResults(
    String detectedDisease,
    double diseaseConfidence,
  ) {
    return Column(
      children: [
        _buildResultTile(
          icon: Icons.bug_report_outlined, // Or appropriate icon
          label: 'Detected Disease',
          value: detectedDisease,
        ),
        _buildResultTile(
          icon: Icons.verified_outlined,
          label: 'Confidence',
          value: _formatConfidence(diseaseConfidence),
          valueColor: _getConfidenceColor(diseaseConfidence),
        ),
      ],
    );
  }

  // Widget to display information for low confidence results
  Widget _buildLowConfidenceInfo(
    String likelyDisease,
    double diseaseConfidence,
  ) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.help_outline, color: Colors.orange),
          title: const Text(
            'Low Confidence Result',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          subtitle: Text(
            'The model is uncertain about the result. This might be due to image quality, an unfamiliar object/plant, or a condition not in its training data.',
            style: KTextStyle.descriptionText.copyWith(fontSize: 12),
          ),
          isThreeLine: true,
        ),
        _buildResultTile(
          icon: Icons.percent_outlined,
          label: 'Confidence',
          value: _formatConfidence(
            diseaseConfidence,
          ), // e.g., "< 10%" or "1.2%"
          valueColor: _getConfidenceColor(diseaseConfidence),
        ),
      ],
    );
  }

  /// Renders simple inline “markdown-ish”: *italic* or **bold** -> bold
  /// We intentionally treat single-star italics as bold for species names like *Puccinia sorghi*.
  Widget _renderMarkdownishBold(
    String text, {
    TextStyle? baseStyle,
    TextStyle? boldStyle,
  }) {
    final spans = <TextSpan>[];
    final base = baseStyle ?? KTextStyle.descriptionText;
    final bold = boldStyle ?? base.copyWith(fontWeight: FontWeight.w600);

    // Matches **bold** or *italic* (we render both as bold)
    final re = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*)');
    int idx = 0;

    for (final m in re.allMatches(text)) {
      if (m.start > idx) {
        spans.add(TextSpan(text: text.substring(idx, m.start), style: base));
      }
      final match = m.group(0)!;
      final inner =
          match.startsWith('**')
              ? match.substring(2, match.length - 2)
              : match.substring(1, match.length - 1);

      spans.add(TextSpan(text: inner, style: bold));
      idx = m.end;
    }
    if (idx < text.length) {
      spans.add(TextSpan(text: text.substring(idx), style: base));
    }
    return RichText(text: TextSpan(children: spans, style: base));
  }

  // Widget to display AI suggestion box
  Widget _buildAiSuggestionBox(String suggestion) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI Suggestion **', style: KTextStyle.titleTealText),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final Color resolvedColor =
                      Theme.of(context).textTheme.bodyMedium?.color ??
                      (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87);
                  final base = KTextStyle.descriptionText.copyWith(
                    color: resolvedColor,
                  );
                  final bold = base.copyWith(fontWeight: FontWeight.w600);
                  return _renderMarkdownishBold(
                    suggestion,
                    baseStyle: base,
                    boldStyle: bold,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _generateSuggestion(
    String detectedDisease,
    double diseaseConfidence,
  ) async {
    final String formatted = UIUtils.formatDiseaseName(detectedDisease);

    // 1. If the result is background (not a leaf)
    if (formatted == 'Background without leaves') {
      return 'Please upload an image that clearly shows a plant leaf.';
    }

    // 2. If confidence is below 30%
    if (diseaseConfidence < 0.3) {
      return 'We are unable to determine whether this is a plant leaf or whether it is diseased. Please try uploading a clearer image.';
    }

    // 3. If the detected result is a healthy label
    if (formatted.endsWith(' healthy')) {
      final plantName = formatted.replaceAll(RegExp(r'\s+healthy$'), '');
      return 'Congratulations! Your $plantName leaf appears to be healthy!';
    }

    // 4. For specific plant diseases, call Gemini to generate advice
    final prompt =
        'What is the best way to identify, manage, or treat the plant disease "$formatted"?';

    try {
      final response = await OpenRouterService().getAnswer(
        prompt,
        model: 'qwen/qwen3-30b-a3b:free',
      );

      // Basic cleanup if needed
      if (response.isEmpty) {
        return 'No suggestion could be generated for "$detectedDisease".';
      }

      return response;
    } catch (e) {
      return 'Error generating suggestion for "$detectedDisease": ${e.toString()}';
    }
  }

  // Helper widget to build a consistent ListTile for each result item
  Widget _buildResultTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColorLight),
      title: Text(label, style: KTextStyle.termTealText),
      subtitle: Text(
        value,
        style: KTextStyle.descriptionText.copyWith(
          color: valueColor ?? KTextStyle.descriptionText.color,
        ),
      ),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  // Helper to get color based on confidence
  Color _getConfidenceColor(double diseaseConfidence) {
    if (diseaseConfidence >= 0.7) return Colors.green.shade600;
    if (diseaseConfidence >= 0.4) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  @override
  void dispose() {
    // Clean up resources
    _backgroundDetectionFuture = null;
    super.dispose();
  }

  // You can now REMOVE the entire _deletePlant method.
  // All logic is handled by _confirmDelete.

  Future<void> _confirmDelete(BuildContext context) async {
    final bool confirmed = await UIUtils.showConfirmationDialog(
      context: context,
      title: 'Delete Analysis',
      message:
          'Are you sure you want to delete this analysis and its associated images? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Colors.red,
    );

    // After the dialog is closed, check if the user confirmed AND if the widget is still mounted.
    // The 'mounted' check is a crucial safeguard in async methods.
    if (confirmed == true && context.mounted) {
      // --- KEY CHANGE ---
      // 1. Navigate AWAY from this page FIRST.
      // This destroys the page and its StreamBuilder before the data can be deleted.
      Navigator.of(context).pop();

      // 2. THEN, start the deletion in the background.
      // The user is already on the previous screen and doesn't need to wait.
      // This is a "fire-and-forget" call.
      _plantService.deletePlant(widget.plantId).catchError((e) {
        // The error is logged, but the user is not interrupted.
        logger.e("Background deletion error (SegmentPage, ignored): $e");

        // Optional: You could use a global SnackBar service to show an error
        // on whatever screen the user is on now, but for a simple case, logging is sufficient.
      });
    }
  }
}
