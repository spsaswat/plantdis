import 'package:uuid/uuid.dart';

class StorageUtils {
  static final _uuid = Uuid();

  /// Generates a timestamp-based ID with UUID
  static String generateTimeBasedId(String prefix) {
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[-:.]'), '')
        .replaceAll(RegExp(r'\d{3}Z$'), 'Z');
    final shortUuid = _uuid.v4().split('-')[0];
    return '${prefix}_${timestamp}_$shortUuid';
  }

  /// Generates a plant ID
  static String generatePlantId() => generateTimeBasedId('plant');

  /// Generates an image ID
  static String generateImageId() => generateTimeBasedId('img');

  /// Gets the storage path for a user's profile image
  static String getUserProfileImagePath(String userId, String extension) {
    return 'users/$userId/profile/avatar.$extension';
  }

  /// Gets the storage path for an original plant image
  static String getOriginalImagePath(
    String userId,
    String plantId,
    String imageId,
    String extension,
  ) {
    return 'users/$userId/plants/$plantId/original/$imageId.$extension';
  }

  /// Gets the storage path for a processed plant image
  static String getProcessedImagePath(
    String userId,
    String plantId,
    String imageId,
    String processType,
    String extension,
  ) {
    return 'users/$userId/plants/$plantId/processed/${imageId}_$processType.$extension';
  }

  /// Gets the storage path for a reference plant image
  static String getReferencePlantImagePath(String imageId, String extension) {
    return 'plants/reference/$imageId.$extension';
  }

  /// Gets the storage path for a community plant image
  static String getCommunityPlantImagePath(String imageId, String extension) {
    return 'plants/community/$imageId.$extension';
  }

  /// Extracts file extension from a file path
  static String getFileExtension(String path) {
    return path.split('.').last.toLowerCase();
  }

  /// Validates if the file extension is an allowed image type
  static bool isValidImageExtension(String extension) {
    const allowedExtensions = ['jpg', 'jpeg', 'png'];
    return allowedExtensions.contains(extension.toLowerCase());
  }

  /// Gets the content type for a file extension
  static String getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  /// Gets the maximum allowed file size in bytes
  static int get maxFileSize => 10 * 1024 * 1024; // 10MB

  /// Checks if a file size is within the allowed limit
  static bool isValidFileSize(int fileSize) {
    return fileSize <= maxFileSize;
  }
}
