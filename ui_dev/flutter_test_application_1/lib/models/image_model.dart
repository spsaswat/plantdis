import 'package:cloud_firestore/cloud_firestore.dart';

class ImageModel {
  final String imageId;
  final String plantId;
  final String userId;
  final String originalUrl;
  final Map<String, String> processedUrls;
  final DateTime uploadTime;
  final Map<String, dynamic>? metadata;

  ImageModel({
    required this.imageId,
    required this.plantId,
    required this.userId,
    required this.originalUrl,
    required this.processedUrls,
    required this.uploadTime,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageId': imageId,
      'plantId': plantId,
      'userId': userId,
      'originalUrl': originalUrl,
      'processedUrls': processedUrls,
      'uploadTime': Timestamp.fromDate(uploadTime),
      'metadata': metadata,
    };
  }

  factory ImageModel.fromMap(Map<String, dynamic> map) {
    return ImageModel(
      imageId: map['imageId'] as String,
      plantId: map['plantId'] as String,
      userId: map['userId'] as String,
      originalUrl: map['originalUrl'] as String,
      processedUrls: Map<String, String>.from(map['processedUrls']),
      uploadTime: (map['uploadTime'] as Timestamp).toDate(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}
