import 'package:flutter_test_application_1/models/image_model.dart';

class ImageFixtures {
  static ImageModel basic = ImageModel(
    imageId: 'img_001',
    plantId: 'plant_001',
    userId: 'user_001',
    originalUrl: 'https://test.com/img_001.jpg',
    processedUrls: {
      'thumbnail': 'https://test.com/thumb_001.jpg',
      'analyzed': 'https://test.com/analyzed_001.jpg',
    },
    uploadTime: DateTime(2025, 1, 1, 12, 0),
    metadata: {'quality': 'high'},
  );
}
