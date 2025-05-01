import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/segment_hero_widget.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:flutter_test_application_1/models/plant_model.dart'; // Import PlantModel

class SegmentPage extends StatefulWidget {
  const SegmentPage({
    super.key,
    required this.imgSrc,
    required this.id,
    this.plantId,
  });

  final String imgSrc;
  final String id;
  final String? plantId;

  @override
  State<SegmentPage> createState() => _SegmentPageState();
}

class _SegmentPageState extends State<SegmentPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _analysisResults;

  @override
  void initState() {
    super.initState();
    _loadPlantData();
  }

  Future<void> _loadPlantData() async {
    if (widget.plantId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Plant ID not provided';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Fetch the specific plant document directly
      DocumentSnapshot plantDoc =
          await _firestore.collection('plants').doc(widget.plantId).get();

      if (!plantDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Plant data not found (ID: ${widget.plantId})';
        });
        return;
      }

      // Convert Firestore data to PlantModel
      PlantModel plant = PlantModel.fromMap(
        plantDoc.data() as Map<String, dynamic>,
      );

      // Check if analysisResults exist
      if (plant.analysisResults == null || plant.analysisResults!.isEmpty) {
        print(
          '[SegmentPage] Loaded plant ${widget.plantId}, but analysisResults are null or empty.',
        );
        // Keep loading false, but results map will be empty, leading to "No analysis results" message.
        setState(() {
          _analysisResults = {};
          _isLoading = false;
        });
      } else {
        setState(() {
          _analysisResults = plant.analysisResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading specific plant data for ${widget.plantId}: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading plant data: $e';
      });
    }
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

  @override
  Widget build(BuildContext context) {
    // Define a low confidence threshold
    const double lowConfidenceThreshold = 0.1; // 10%

    // Determine display state based on results and confidence
    bool hasResults = _analysisResults != null && _analysisResults!.isNotEmpty;
    double confidence = 0.0;
    if (hasResults && _analysisResults!['confidence'] != null) {
      confidence =
          (_analysisResults!['confidence'] as num).toDouble(); // Ensure double
    }
    bool isLowConfidence = hasResults && confidence < lowConfidenceThreshold;
    String detectedDisease = 'N/A'; // Initialize
    if (hasResults) {
      detectedDisease =
          _analysisResults!['detectedDisease']?.toString() ?? 'N/A';
    }

    // **** Add Debug Prints ****
    print('[SegmentPage build] plantId: ${widget.plantId}');
    print('[SegmentPage build] isLoading: $_isLoading');
    print('[SegmentPage build] errorMessage: $_errorMessage');
    print('[SegmentPage build] _analysisResults: $_analysisResults');
    print('[SegmentPage build] hasResults: $hasResults');
    print('[SegmentPage build] confidence: $confidence');
    print('[SegmentPage build] isLowConfidence: $isLowConfidence');
    print('[SegmentPage build] detectedDisease: $detectedDisease');
    // **** End Debug Prints ****

    return Scaffold(
      appBar: AppbarWidget(),
      body: Center(
        heightFactor: 1,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FractionallySizedBox(
                  widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                  child:
                      _isLoading
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 20),
                                Text('Loading plant analysis...'),
                              ],
                            ),
                          )
                          : _errorMessage.isNotEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                SizedBox(height: 20),
                                Text(_errorMessage),
                                SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _loadPlantData,
                                  child: Text('Try Again'),
                                ),
                              ],
                            ),
                          )
                          : Column(
                            spacing: 10.0,
                            children: [
                              SegmentHero(imgSrc: widget.imgSrc, id: widget.id),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 10.0),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(15.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      spacing: 5.0,
                                      children: [
                                        Center(
                                          child: Text(
                                            "Analysis Results",
                                            style: KTextStyle.titleTealText,
                                          ),
                                        ),
                                        SizedBox(
                                          height: 10,
                                        ), // Add some spacing
                                        // --- Start Refactored Results Display ---
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
                                              detectedDisease,
                                              confidence,
                                            )
                                          else
                                            _buildStandardResults(
                                              detectedDisease,
                                              confidence,
                                            ),

                                          // Always show detection time if available
                                          _buildResultTile(
                                            icon: Icons.timer_outlined,
                                            label: 'Detection Time',
                                            value: _formatTimestamp(
                                              _analysisResults!['detectionTimestamp']
                                                  ?.toString(),
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
                                              style: KTextStyle.descriptionText,
                                            ),
                                          ),
                                        // --- End Refactored Results Display ---
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                );
              },
            ),
          ),
        ),
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
}
