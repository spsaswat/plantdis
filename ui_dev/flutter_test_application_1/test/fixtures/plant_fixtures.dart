import 'package:flutter_test_application_1/models/plant_model.dart';

/// Predefined PlantModel fixtures for testing.
class PlantFixtures {
  /// A completed plant with analysis results
  static PlantModel completed = PlantModel(
    plantId: 'plant_completed_001',
    userId: 'user_001',
    createdAt: DateTime(2025, 1, 1, 10, 0),
    status: 'completed',
    images: ['img_completed_1'],
    analysisResults: {
      'primary_disease': 'leaf_spot',
      'confidence': 0.9,
    },
  );
   
  /// A pending plant still under analysis
  static PlantModel pending = PlantModel(
    plantId: 'plant_pending_001',
    userId: 'user_002',
    createdAt: DateTime(2025, 1, 2, 11, 0),
    status: 'pending',
    images: ['img_pending_1'],
    analysisResults: null,
  );

  /// A mixed list (1 completed + 1 pending)
  static List<PlantModel> mixedList = [
    completed,
    pending,
  ];
}
