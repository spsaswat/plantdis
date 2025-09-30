import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/services/segmentation_service.dart';

void main() {
  group('SegmentationService lifecycle', () {
    test('dispose() resets loaded state', () {
      final seg = SegmentationService();
      expect(seg.isModelLoaded, isFalse);
      seg.dispose();
      expect(seg.isModelLoaded, isFalse, reason: 'Should remain false after dispose');
    });

    test('dispose() is idempotent', () {
      final seg = SegmentationService();
      seg.dispose();
      // Calling dispose twice should not throw
      seg.dispose();
      expect(seg.isModelLoaded, isFalse);
    });
  });
}
