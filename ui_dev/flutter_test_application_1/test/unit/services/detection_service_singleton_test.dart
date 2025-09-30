import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/services/detection_service.dart';

// Verifies the factory-based singleton semantics of DetectionService:
// two factory calls return the same instance during the process lifetime.
// Note: We do not call loadModel() to avoid touching the concrete implementation.
// Ref: detection_service.dart
void main() {
  test('DetectionService factory returns a singleton instance', () {
    final s1 = DetectionService();
    final s2 = DetectionService();
    expect(identical(s1, s2), isTrue, reason: 'Factory should cache a single instance');
  });
}
