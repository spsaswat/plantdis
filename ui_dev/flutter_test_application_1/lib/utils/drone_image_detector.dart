import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter_test_application_1/utils/logger.dart';
import 'package:path/path.dart' as p;

/// Returns true when EXIF metadata or filename suggests a consumer drone capture.
Future<bool> isDroneImageForPath(String path) => isDroneImage(File(path));

/// Returns true when EXIF metadata or filename suggests a consumer drone capture.
Future<bool> isDroneImage(File imageFile) async {
  try {
    final bytes = await imageFile.readAsBytes();
    final tags = await readExifFromBytes(bytes);

    final fileName = p.basename(imageFile.path).toLowerCase();

    final make = tags['Image Make']?.printable.toLowerCase() ?? '';
    final model = tags['Image Model']?.printable.toLowerCase() ?? '';
    final software = tags['Image Software']?.printable.toLowerCase() ?? '';

    const droneKeywords = [
      'dji',
      'mavic',
      'phantom',
      'inspire',
      'matrice',
      'mini',
      'air',
      'm3m',
      'autel',
      'parrot',
      'skydio',
      'potensic',
      'atom',
      'yuneec',
    ];

    final hasDroneFileName =
        fileName.startsWith('dji_') || fileName.contains('_d.');

    final hasDroneMetadata = droneKeywords.any((keyword) {
      return make.contains(keyword) ||
          model.contains(keyword) ||
          software.contains(keyword);
    });

    return hasDroneFileName || hasDroneMetadata;
  } catch (e, st) {
    logger.w('Error reading EXIF for drone check: $e\n$st');
    return false;
  }
}
