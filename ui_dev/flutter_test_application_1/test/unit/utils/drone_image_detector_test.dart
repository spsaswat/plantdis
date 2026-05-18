import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/utils/drone_image_detector.dart';
import 'package:path/path.dart' as p;

void main() {
  test('isDroneImage returns true for DJI-style filename without EXIF', () async {
    final dir = await Directory.systemTemp.createTemp('drone_test_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final file = File(p.join(dir.path, 'DJI_0123_d.JPG'));
    await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);

    expect(await isDroneImage(file), isTrue);
  });

  test('isDroneImage returns false for generic filename without drone EXIF', () async {
    final dir = await Directory.systemTemp.createTemp('drone_test_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final file = File(p.join(dir.path, 'vacation_photo.jpg'));
    await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);

    expect(await isDroneImage(file), isFalse);
  });
}
