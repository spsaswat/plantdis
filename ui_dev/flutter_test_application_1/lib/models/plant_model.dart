import 'package:cloud_firestore/cloud_firestore.dart';

class PlantModel {
  final String plantId;
  final String userId;
  final DateTime createdAt;
  final String status;
  final List<String> images;
  final Map<String, dynamic>? analysisResults;

  PlantModel({
    required this.plantId,
    required this.userId,
    required this.createdAt,
    required this.status,
    required this.images,
    this.analysisResults,
  });

  Map<String, dynamic> toMap() {
    return {
      'plantId': plantId,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'images': images,
      'analysisResults': analysisResults,
    };
  }

  factory PlantModel.fromMap(Map<String, dynamic> map) {
    return PlantModel(
      plantId: map['plantId'] as String,
      userId: map['userId'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] as String,
      images: List<String>.from(map['images']),
      analysisResults: map['analysisResults'] as Map<String, dynamic>?,
    );
  }

  PlantModel copyWith({
    String? plantId,
    String? userId,
    DateTime? createdAt,
    String? status,
    List<String>? images,
    Map<String, dynamic>? analysisResults,
  }) {
    return PlantModel(
      plantId: plantId ?? this.plantId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      images: images ?? this.images,
      analysisResults: analysisResults ?? this.analysisResults,
    );
  }
}
