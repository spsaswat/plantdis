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

      // Run background detection
      final backgroundResult = await _backgroundDetectionService.detectLeaves(
        imageBytes: imageBytes,
        confidenceThreshold:
            0.8, // 80% probability threshold for background detection
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

  /// Trigger plant analysis workflow (segmentation + disease detection)
  Future<void> _triggerPlantAnalysis() async {
    if (_isAnalysisTriggered) return; // Prevent duplicate triggers

    setState(() {
      _isAnalysisTriggered = true;
    });

    try {
      // Update plant status to processing
      await _firestore.collection('plants').doc(widget.plantId).update({
        'status': 'processing',
        'analysisError': null,
      });

      if (kDebugMode) {
        logger.i('[SegmentPage] Started plant analysis for ${widget.plantId}');
      }

      // The actual analysis will be handled by the backend/cloud functions
      // This just triggers the process by updating the status
    } catch (e, stackTrace) {
      logger.e('[SegmentPage] Error triggering analysis: $e\n$stackTrace');

      // Update status to error
      await _firestore.collection('plants').doc(widget.plantId).update({
        'status': 'error',
        'analysisError': 'Failed to trigger analysis: ${e.toString()}',
      });
    }
  }

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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('plants').doc(widget.plantId).snapshots(),
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                                              style: KTextStyle.titleTealText,
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
                                              style: KTextStyle.titleTealText,
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
                                                  textAlign: TextAlign.center,
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
                                      (result['backgroundProbability'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final method =
                                      result['method'] as String? ?? 'unknown';

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
                                              style: KTextStyle.titleTealText,
                                            ),
                                          ),
                                          const SizedBox(height: 15),
                                          ListTile(
                                            leading: Icon(
                                              hasLeaves
                                                  ? Icons.eco
                                                  : Icons.image_not_supported,
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
                                                    color: Colors.grey.shade600,
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
                                              result['greenRatio'] != null &&
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
                                                padding: const EdgeInsets.only(
                                                  top: 2.0,
                                                ),
                                                child: Text(
                                                  result['note'].toString(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.orange.shade700,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                          ],
                                          if (hasLeaves)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10.0,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  10.0,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        8.0,
                                                      ),
                                                  border: Border.all(
                                                    color:
                                                        Colors.green.shade200,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .check_circle_outline,
                                                      color:
                                                          Colors.green.shade600,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
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
                                              padding: const EdgeInsets.only(
                                                top: 10.0,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  10.0,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        8.0,
                                                      ),
                                                  border: Border.all(
                                                    color:
                                                        Colors.orange.shade200,
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
                                                    const SizedBox(width: 8),
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

                          // Check if background detection indicates no leaves (high background probability = no leaves)
                          // Only show subsequent content if leaves are detected
                          if (_isBackgroundDetectionComplete &&
                              _backgroundDetectionResult != null &&
                              _backgroundDetectionResult!['error'] == null) ...[
                            // Check if background detection shows high probability for background (no leaves)
                            // Note: backgroundProbability = probability of being background without leaves
                            if (((_backgroundDetectionResult!['backgroundProbability']
                                                as num?)
                                            ?.toDouble() ??
                                        0.0) >=
                                    (1 - decisionThreshold) ||
                                !(_backgroundDetectionResult!['hasLeaves']
                                        as bool? ??
                                    true)) ...[
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
                                          padding: const EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8.0,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                color: Colors.orange.shade600,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Background probability is ${(((_backgroundDetectionResult!['backgroundProbability'] as num?)?.toDouble() ?? 0.0) * 100).toStringAsFixed(1)}%. This image appears to contain only background without plant leaves.',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.orange.shade700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              // Show subsequent content only if leaves are detected
                              // Auto-trigger analysis if not already triggered and plant is not processing/completed
                              if (!_isAnalysisTriggered &&
                                  status != 'processing' &&
                                  status != 'analyzing' &&
                                  status != 'completed') ...[
                                // Trigger analysis automatically
                                FutureBuilder<void>(
                                  future: _triggerPlantAnalysis(),
                                  builder: (context, snapshot) {
                                    return const Padding(
                                      padding: EdgeInsets.only(top: 15.0),
                                      child: Card(
                                        child: Padding(
                                          padding: EdgeInsets.all(15.0),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.auto_fix_high,
                                                size: 48,
                                                color: Colors.blue,
                                              ),
                                              SizedBox(height: 16),
                                              Text(
                                                'Plant Leaves Detected!',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                'Starting automatic segmentation and disease analysis...',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              SizedBox(height: 16),
                                              CircularProgressIndicator(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],

                              // Check for segmentation result in analysisResults
                              if (hasResults &&
                                  analysisResults['segmentationUrl'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 15.0),
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Center(
                                            child: Text(
                                              "Segmentation Result",
                                              style: KTextStyle.titleTealText,
                                            ),
                                          ),
                                          const SizedBox(height: 15),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              5.0,
                                            ),
                                            child: Image.network(
                                              analysisResults['segmentationUrl'],
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
                                                    color: Colors.grey.shade200,
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
                                                          Icons.broken_image,
                                                          size: 48,
                                                          color: Colors.grey,
                                                        ),
                                                        SizedBox(height: 8),
                                                        Text(
                                                          'Failed to load image',
                                                          style: TextStyle(
                                                            color: Colors.grey,
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
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Container(
                                                  width: double.infinity,
                                                  height: 200,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
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
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

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
                                            style: KTextStyle.titleTealText,
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
                                                  () => _confirmDelete(context),
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
                                        else if (status == 'completed') ...[
                                          if (hasResults) ...[
                                            if (detectedDisease ==
                                                'No disease detected')
                                              const ListTile(
                                                leading: Icon(
                                                  Icons.check_circle_outline,
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
                                              padding: const EdgeInsets.only(
                                                top: 16.0,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  TextButton.icon(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.red,
                                                    ),
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                    ),
                                                    label: const Text(
                                                      'Delete Result',
                                                    ),
                                                    onPressed:
                                                        () => _confirmDelete(
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
                                            subtitle: Text('Status: $status'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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
    // 1. If the result is background (not a leaf)
    if (detectedDisease == 'Background without leaves') {
      return 'Please upload an image that clearly shows a plant leaf.';
    }

    // 2. If confidence is below 30%
    if (diseaseConfidence < 0.3) {
      return 'We are unable to determine whether this is a plant leaf or whether it is diseased. Please try uploading a clearer image.';
    }

    // 3. If the detected result is a healthy label
    if (detectedDisease.endsWith(' healthy') ||
        detectedDisease.endsWith('_healthy')) {
      final plantName = detectedDisease
          .replaceAll('_healthy', '')
          .replaceAll(' healthy', '');
      return 'Congratulations! Your $plantName leaf appears to be healthy!';
    }

    // 4. For specific plant diseases, call Gemini to generate advice

    final prompt =
        'What is the best way to identify, manage, or treat the plant disease "$detectedDisease"?';

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
