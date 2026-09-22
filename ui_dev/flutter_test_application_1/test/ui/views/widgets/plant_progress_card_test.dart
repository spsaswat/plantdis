import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/services/detection_service.dart';
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:flutter_test_application_1/views/widgets/plant_progress_card.dart';
import 'package:flutter_test_application_1/views/widgets/analysis_progress_widget.dart';

void main() {
  testWidgets('Missing session shows plant ID and no active thumbnail', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PlantProgressCard(plantId: 'missing-session')),
      ),
    );
    expect(
      find.text(
        'Analysis session for Plant ID missing-session not active or already completed.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ClipRRect), findsNothing);
  });

  testWidgets(
    'Active session shows thumbnail placeholder and receives progress',
    (tester) async {
      final service = DetectionService();
      const id = 'active-session';
      service.startProgressTracking(id);
      addTearDown(
        () => service.updateProgress(
          id,
          AnalysisProgress(
            stage: AnalysisStage.completed,
            progress: 1,
            message: 'Complete',
          ),
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PlantProgressCard(plantId: id))),
      );
      await tester.pump();
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      service.updateProgress(
        id,
        AnalysisProgress(
          stage: AnalysisStage.detecting,
          progress: 0.4,
          message: 'Detecting test plant',
        ),
      );
      await tester.idle();
      await tester.pump();
      final progress =
          tester
              .widget<AnalysisProgressWidget>(
                find.byType(AnalysisProgressWidget),
              )
              .progress;
      expect(progress.stage, AnalysisStage.detecting);
      expect(progress.progress, 0.4);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('40%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
