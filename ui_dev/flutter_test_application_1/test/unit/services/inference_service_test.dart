import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/services/inference_service.dart';
import 'package:flutter_test_application_1/models/analysis_progress.dart';

void main() {
  group('InferenceService', () {
    test('simulateAnalysis emits stages in order and completes', () async {
      final service = InferenceService();
      final received = <AnalysisStage>[];
      final messages = <String?>[];

      final sub = service.progressStream.listen((p) {
        received.add(p.stage);
        messages.add(p.message);
      });

      await service.simulateAnalysis(plantId: 'plant_sim');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(received.isNotEmpty, true);
      expect(received.last, AnalysisStage.completed);

      int rank(AnalysisStage s) {
        switch (s) {
          case AnalysisStage.preprocessing:
            return 0;
          case AnalysisStage.detecting:
            return 1;
          case AnalysisStage.postprocessing:
            return 2;
          case AnalysisStage.completed:
            return 3;
          case AnalysisStage.failed:
            return 99;
        }
      }

      int last = -1;
      for (final s in received) {
        final r = rank(s);
        expect(r >= last, true);
        last = r;
      }

      expect(messages.whereType<String>().isNotEmpty, true);

      await sub.cancel();
      service.dispose();
    });

    test('analyzeImage emits Failed stage on error', () async {
      final service = InferenceService();
      final receivedStages = <AnalysisStage>[];

      final sub = service.progressStream.listen((p) {
        receivedStages.add(p.stage);
      });

      final result = await service.analyzeImage(
        imageBytes: Uint8List(0),
        plantId: 'plant_err',
        isSegmented: false,
      );

      expect(result, isNull);
      expect(receivedStages.contains(AnalysisStage.failed), isTrue);

      await sub.cancel();
      service.dispose();
    }, skip: true);
  });
}
