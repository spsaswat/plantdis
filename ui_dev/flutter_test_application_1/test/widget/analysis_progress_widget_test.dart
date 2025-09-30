import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:flutter_test_application_1/views/widgets/analysis_progress_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('AnalysisProgressWidget shows percent and stage label', (
    tester,
  ) async {
    final progress = AnalysisProgress(
      stage: AnalysisStage.detecting,
      progress: 0.42,
      message: 'Detecting',
    );
    await tester.pumpWidget(wrap(AnalysisProgressWidget(progress: progress)));

    // Initial frame starts at 0 then animates
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('42%'), findsOneWidget);
    expect(find.text(progress.stageLabel), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AnalysisProgressWidget can show ETA text', (tester) async {
    final progress = AnalysisProgress(
      stage: AnalysisStage.postprocessing,
      progress: 0.75,
      message: 'Almost done',
    );
    await tester.pumpWidget(wrap(AnalysisProgressWidget(progress: progress)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('~3s remaining'), findsOneWidget);
  });
}
