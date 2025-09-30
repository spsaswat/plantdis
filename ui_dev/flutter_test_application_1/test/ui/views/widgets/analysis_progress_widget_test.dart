import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:flutter_test_application_1/views/widgets/analysis_progress_widget.dart';

void main() {
  group('AnalysisProgressWidget Tests', () {
    Widget wrapWithMaterialApp(Widget child) {
      return MaterialApp(home: Scaffold(body: child));
    }

    testWidgets('displays preprocessing stage elements', (tester) async {
      final progress = AnalysisProgress(
        stage: AnalysisStage.preprocessing,
        progress: 0.3,
        message: 'Preparing data...',
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(AnalysisProgressWidget(progress: progress)),
      );
      await tester.pumpAndSettle();

      expect(find.text(progress.stageLabel), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is ProgressIndicator),
        findsOneWidget,
      );
    });

    testWidgets('shows detecting stage elements', (tester) async {
      final progress = AnalysisProgress(
        stage: AnalysisStage.detecting,
        progress: 0.6,
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(AnalysisProgressWidget(progress: progress)),
      );
      await tester.pumpAndSettle();

      expect(find.text(progress.stageLabel), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is ProgressIndicator),
        findsOneWidget,
      );
    });

    testWidgets('displays post-processing stage elements', (tester) async {
      final progress = AnalysisProgress(
        stage: AnalysisStage.postprocessing,
        progress: 0.8,
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(AnalysisProgressWidget(progress: progress)),
      );
      await tester.pumpAndSettle();

      expect(find.text(progress.stageLabel), findsOneWidget);

      if (progress.estimatedRemaining != null) {
        final seconds = progress.estimatedRemaining!.inSeconds;
        expect(find.textContaining(seconds.toString()), findsOneWidget);
      }
    });


    testWidgets('handles progress 0 case', (tester) async {
      final progress = AnalysisProgress(
        stage: AnalysisStage.preprocessing,
        progress: 0.0,
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(AnalysisProgressWidget(progress: progress)),
      );
      await tester.pumpAndSettle();

      expect(find.text(progress.stageLabel), findsOneWidget);
      expect(find.textContaining('remaining'), findsNothing);
    });
  });
}
