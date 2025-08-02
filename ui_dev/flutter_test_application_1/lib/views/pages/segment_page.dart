import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/segment_hero_widget.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:flutter_test_application_1/models/plant_model.dart'; // Import PlantModel
import 'package:flutter_test_application_1/services/plant_service.dart'; // Import PlantService
import 'package:flutter_test_application_1/utils/ui_utils.dart'; // Import UIUtils
import 'dart:async'; // Import for TimeoutException
import 'dart:io' as io;
import '../services/openrouter_service.dart';

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

  @override
  Widget build(BuildContext context) {
    // Define a low confidence threshold
    const double lowConfidenceThreshold = 0.1; // 10%

    return Scaffold(
      appBar: AppbarWidget(),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('plants').doc(widget.plantId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
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
            print(
              'Error in StreamBuilder for plant ${widget.plantId}: ${snapshot.error}',
            );
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 20),
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
                    Icon(
                      Icons.info_outline, // Changed icon
                      size: 60,
                      color: Colors.blueGrey, // Changed color
                    ),
                    SizedBox(height: 25),
                    Text(
                      'Plant Data Unavailable', // Changed title
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 15),
                    Text(
                      'This plant data (ID: ${widget.plantId}) cannot be displayed. It might have been deleted or is still processing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400], // Adjusted color
                        height: 1.4, // Added line height
                      ),
                    ),
                    SizedBox(height: 30),
                    ElevatedButton.icon(
                      icon: Icon(Icons.arrow_back),
                      label: Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        // Use primary color for button background
                        foregroundColor: Colors.white, // White text
                        padding: EdgeInsets.symmetric(
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
          double confidence = 0.0;
          if (hasResults && analysisResults['confidence'] != null) {
            confidence = (analysisResults['confidence'] as num).toDouble();
          }
          bool isLowConfidence =
              hasResults && confidence < lowConfidenceThreshold;
          String detectedDisease = 'N/A';
          if (hasResults) {
            detectedDisease =
                analysisResults['detectedDisease']?.toString() ?? 'N/A';
          }

          // Format the displayed disease name to show spaces instead of underscores
          String displayDiseaseName = UIUtils.formatDiseaseName(
            detectedDisease,
          );

          // Debug prints inside StreamBuilder
          // print('[SegmentPage StreamBuilder] plantId: ${widget.plantId}');
          // print('[SegmentPage StreamBuilder] status: $status');
          // print('[SegmentPage StreamBuilder] analysisResults: $analysisResults');
          // print('[SegmentPage StreamBuilder] hasResults: $hasResults');
          // print('[SegmentPage StreamBuilder] confidence: $confidence');
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
                                      Center(
                                        child: Text(
                                          "Segmentation Result",
                                          style: KTextStyle.titleTealText,
                                        ),
                                      ),
                                      SizedBox(height: 15),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          5.0,
                                        ),
                                        child: Image.network(
                                          analysisResults['segmentationUrl'],
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 10.0),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 5.0,
                                  children: [
                                    Center(
                                      child: Text(
                                        "Analysis Results",
                                        style: KTextStyle.titleTealText,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    // Handle different statuses
                                    if (status == 'processing' ||
                                        status == 'analyzing')
                                      ListTile(
                                        leading: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                        title: Text('Analysis in progress...'),
                                        subtitle: Text(
                                          'Results will appear here shortly.',
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(
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
                                        leading: Icon(
                                          Icons.error_outline,
                                          color: Colors.red,
                                        ),
                                        title: Text('Analysis Failed'),
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
                                          ListTile(
                                            leading: Icon(
                                              Icons.check_circle_outline,
                                              color: Colors.green,
                                            ),
                                            title: Text('Analysis Completed'),
                                            subtitle: Text(
                                              'No disease detected above the confidence threshold.',
                                            ),
                                          )
                                        else if (isLowConfidence)
                                          _buildLowConfidenceInfo(
                                            displayDiseaseName,
                                            confidence,
                                          )
                                        else
                                          _buildStandardResults(
                                            displayDiseaseName,
                                            confidence,
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
                                                  foregroundColor: Colors.red,
                                                ),
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                ),
                                                label: Text('Delete Result'),
                                                onPressed:
                                                    () =>
                                                        _confirmDelete(context),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else
                                        ListTile(
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
                                        leading: Icon(
                                          Icons.hourglass_empty,
                                          color: Colors.grey,
                                        ),
                                        title: Text('Analysis Pending'),
                                        subtitle: Text('Status: $status'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          FutureBuilder<String>(
                            future: _generateSuggestion(detectedDisease, confidence),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return _buildAiSuggestionBox('Generating AI suggestion...');
                              } else if (snapshot.hasError) {
                                return _buildAiSuggestionBox('Failed to generate suggestion.');
                              } else {
                                return _buildAiSuggestionBox(snapshot.data ?? 'No suggestion available.');
                              }
                            },
                          ),
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
  Widget _buildStandardResults(String disease, double confidence) {
    return Column(
      children: [
        _buildResultTile(
          icon: Icons.bug_report_outlined, // Or appropriate icon
          label: 'Detected Disease',
          value: disease,
        ),
        _buildResultTile(
          icon: Icons.verified_outlined,
          label: 'Confidence',
          value: _formatConfidence(confidence),
          valueColor: _getConfidenceColor(confidence),
        ),
      ],
    );
  }

  // Widget to display information for low confidence results
  Widget _buildLowConfidenceInfo(String likelyDisease, double confidence) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.help_outline, color: Colors.orange),
          title: Text(
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
          icon: Icons.label_important_outline,
          label: 'Most Likely Detection (uncertain)',
          value: likelyDisease,
        ),
        _buildResultTile(
          icon: Icons.percent_outlined,
          label: 'Confidence',
          value: _formatConfidence(confidence), // e.g., "< 10%" or "1.2%"
          valueColor: _getConfidenceColor(confidence),
        ),
      ],
    );
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
              Text(
                'AI Suggestion',
                style: KTextStyle.titleTealText,
              ),
              const SizedBox(height: 8),
              Text(
                suggestion,
                style: KTextStyle.descriptionText,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<String> _generateSuggestion(String disease, double confidence) async {
    // 1. If the result is background (not a leaf)
    if (disease == 'Background_without_leaves') {
      return 'Please upload an image that clearly shows a plant leaf.';
    }

    // 2. If confidence is below 80%
    if (confidence < 0.8) {
      return 'We are unable to determine whether this is a plant leaf or whether it is diseased. Please try uploading a clearer image.';
    }

    // 3. If the detected result is a healthy label
    if (disease.endsWith('_healthy')) {
      final plantName = disease.replaceAll('_healthy', '');
      return 'Congratulations! Your $plantName leaf appears to be healthy!';
    }

    // 4. For specific plant diseases, call Gemini to generate advice

    final prompt =
        'What is the best way to identify, manage, or treat the plant disease "$disease"?';

    try {
      final response = await OpenRouterService().getAnswer(
        prompt,
        model: 'qwen/qwen3-30b-a3b:free',
      );

      // Basic cleanup if needed
      if (response.isEmpty) {
        return 'No suggestion could be generated for "$disease".';
      }

      return response;
    } catch (e) {
      return 'Error generating suggestion for "$disease": ${e.toString()}';
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
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green.shade600;
    if (confidence >= 0.4) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool confirm = await UIUtils.showConfirmationDialog(
      context: context,
      title: 'Delete Analysis',
      message:
          'Are you sure you want to delete this analysis and its associated images? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Colors.red,
    );

    if (confirm) {
      _deletePlant(context);
    }
  }

  Future<void> _deletePlant(BuildContext context) async {
    try {
      // Show the auto-dismissing deletion dialog
      UIUtils.showDeletionDialog(
        context,
        'Deleting analysis...\nDeletion will continue in the background.',
        timeoutSeconds: 3, // Show briefly
      );

      // Start deletion in background immediately
      _plantService.deletePlant(widget.plantId).catchError((e) {
        // Log background errors but don't bother the user
        print("Background deletion error (SegmentPage, ignored): $e");
      });

      // Navigate back immediately
      if (Navigator.of(context).canPop()) {
        Future.delayed(Duration(milliseconds: 50), () {
          // Small delay before pop
          if (context.mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      // Handle any errors *before* deletion starts (e.g., showing dialog failed)
      if (context.mounted) {
        UIUtils.showErrorSnackBar(context, 'Failed to initiate deletion: $e');
      }
    }
  }
}