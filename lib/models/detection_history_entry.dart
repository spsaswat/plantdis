import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:intl/intl.dart';

/// A wrapper class for PlantModel that adds functionality specific to history views
class DetectionHistoryEntry {
  final PlantModel plant;

  DetectionHistoryEntry(this.plant);

  /// Gets the actual detected disease name or a placeholder
  String get diseaseName {
    if (plant.analysisResults == null || plant.analysisResults!.isEmpty) {
      return plant.status == 'error' ? 'Analysis Failed' : 'No Results';
    }

    final detectedDisease = plant.analysisResults!['detectedDisease'];
    if (detectedDisease == null) return 'Unknown';
    if (detectedDisease == 'No disease detected')
      return 'No Disease Detected (Healthy)';

    return detectedDisease.toString();
  }

  /// Gets the confidence as a double or 0.0 if not available
  double get confidence {
    if (plant.analysisResults == null || plant.analysisResults!.isEmpty) {
      return 0.0;
    }

    final confidenceValue = plant.analysisResults!['confidence'];
    if (confidenceValue == null) return 0.0;

    return (confidenceValue is double)
        ? confidenceValue
        : (confidenceValue is int)
        ? confidenceValue.toDouble()
        : 0.0;
  }

  /// Gets a formatted date of when the analysis was performed
  String get analysisDate {
    final formatter = DateFormat('MMM d, yyyy');

    if (plant.analysisResults != null &&
        plant.analysisResults!['detectionTimestamp'] != null) {
      try {
        final timestamp =
            plant.analysisResults!['detectionTimestamp'].toString();
        return formatter.format(DateTime.parse(timestamp));
      } catch (e) {
        // Fall back to createdAt if parsing fails
      }
    }

    return formatter.format(plant.createdAt);
  }

  /// Gets the ID of the image that was analyzed
  String? get analyzedImageId {
    return plant.lastAnalyzedImageId ??
        (plant.images.isNotEmpty ? plant.images.first : null);
  }

  /// Gets plant type from the results (if available)
  String get plantType {
    if (plant.analysisResults == null || plant.analysisResults!.isEmpty) {
      return 'Unknown';
    }

    final disease = diseaseName;
    if (disease.contains('_')) {
      // Extract plant type from disease name (e.g., "Apple_scab" → "Apple")
      return disease.split('_').first;
    }

    return 'Unknown';
  }

  /// Returns true if this entry represents an error state
  bool get isError => plant.status == 'error';

  /// Returns true if this entry has valid analysis results
  bool get hasResults =>
      plant.analysisResults != null &&
      plant.analysisResults!.isNotEmpty &&
      plant.status == 'completed';

  /// Returns a color-coded status for the result
  String get status {
    if (plant.status == 'error') return 'Failed';
    if (plant.status == 'completed') return 'Completed';
    if (plant.status == 'processing' || plant.status == 'analyzing')
      return 'Processing';
    return 'Pending';
  }
}
