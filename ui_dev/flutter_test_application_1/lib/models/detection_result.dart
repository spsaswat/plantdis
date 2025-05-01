import 'package:cloud_firestore/cloud_firestore.dart';

class BoundingBox {
  final double xMin, yMin, xMax, yMax;

  BoundingBox({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  Map<String, double> toJson() => {
    'xMin': xMin,
    'yMin': yMin,
    'xMax': xMax,
    'yMax': yMax,
  };

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      xMin: (json['xMin'] as num).toDouble(),
      yMin: (json['yMin'] as num).toDouble(),
      xMax: (json['xMax'] as num).toDouble(),
      yMax: (json['yMax'] as num).toDouble(),
    );
  }
}

class DetectionResult {
  final String diseaseName;
  final double confidence;
  final BoundingBox? boundingBox;
  final String? id;
  final DateTime? timestamp;

  const DetectionResult({
    required this.diseaseName,
    required this.confidence,
    this.boundingBox,
    this.id,
    this.timestamp,
  });

  factory DetectionResult.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return DetectionResult(
      id: documentId,
      diseaseName: data['disease_name'] as String,
      confidence: (data['confidence'] as num).toDouble(),
      boundingBox:
          data['bounding_box'] != null
              ? BoundingBox.fromJson(
                data['bounding_box'] as Map<String, dynamic>,
              )
              : null,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  // Add toMap method for Firestore serialization
  Map<String, dynamic> toMap() {
    return {
      'diseaseName': diseaseName,
      'confidence': confidence,
      'boundingBox': boundingBox?.toJson(), // Use toJson if exists
      // 'id' is usually the document ID, not stored in the map itself
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }
}
