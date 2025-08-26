import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/models/analysis_progress.dart';

void main() {
  group('AnalysisStage', () {
    test('should have all expected enum values', () {
      // Assert all enum values exist
      expect(AnalysisStage.values, contains(AnalysisStage.preprocessing));
      expect(AnalysisStage.values, contains(AnalysisStage.detecting));
      expect(AnalysisStage.values, contains(AnalysisStage.postprocessing));
      expect(AnalysisStage.values, contains(AnalysisStage.completed));
      expect(AnalysisStage.values, contains(AnalysisStage.failed));
      expect(AnalysisStage.values.length, 5);
    });
  });

  group('AnalysisProgress', () {
    test('should create instance with all required fields', () {
      // Arrange & Act
      final progress = AnalysisProgress(
        stage: AnalysisStage.detecting,
        progress: 0.5,
        message: 'Analyzing plant image...',
        errorMessage: null,
      );

      // Assert
      expect(progress.stage, AnalysisStage.detecting);
      expect(progress.progress, 0.5);
      expect(progress.message, 'Analyzing plant image...');
      expect(progress.errorMessage, isNull);
    });

    test('should create instance with minimal required fields', () {
      // Arrange & Act
      final progress = AnalysisProgress(
        stage: AnalysisStage.preprocessing,
        progress: 0.1,
      );

      // Assert
      expect(progress.stage, AnalysisStage.preprocessing);
      expect(progress.progress, 0.1);
      expect(progress.message, isNull);
      expect(progress.errorMessage, isNull);
    });

    test('should calculate estimated remaining time correctly', () {
      // Test with 50% progress (should have ~6 seconds remaining)
      final progress50 = AnalysisProgress(
        stage: AnalysisStage.detecting,
        progress: 0.5,
      );
      expect(progress50.estimatedRemaining, Duration(seconds: 6));

      // Test with 75% progress (should have ~3 seconds remaining)
      final progress75 = AnalysisProgress(
        stage: AnalysisStage.postprocessing,
        progress: 0.75,
      );
      expect(progress75.estimatedRemaining, Duration(seconds: 3));

      // Test with 90% progress (should have ~1 second remaining)
      final progress90 = AnalysisProgress(
        stage: AnalysisStage.postprocessing,
        progress: 0.9,
      );
      expect(progress90.estimatedRemaining, Duration(seconds: 1));
    });

    test('should return null estimated time when progress is 0', () {
      // Arrange & Act
      final progress = AnalysisProgress(
        stage: AnalysisStage.preprocessing,
        progress: 0.0,
      );

      // Assert
      expect(progress.estimatedRemaining, isNull);
    });

    test('should return 0 seconds when progress is complete', () {
      // Arrange & Act
      final progress = AnalysisProgress(
        stage: AnalysisStage.completed,
        progress: 1.0,
      );

      // Assert
      expect(progress.estimatedRemaining, Duration(seconds: 0));
    });

    test('should provide correct stage labels', () {
      // Test all stage labels
      expect(AnalysisProgress(
        stage: AnalysisStage.preprocessing,
        progress: 0.1,
      ).stageLabel, 'Preprocessing');

      expect(AnalysisProgress(
        stage: AnalysisStage.detecting,
        progress: 0.5,
      ).stageLabel, 'Detecting');

      expect(AnalysisProgress(
        stage: AnalysisStage.postprocessing,
        progress: 0.8,
      ).stageLabel, 'Post-processing');

      expect(AnalysisProgress(
        stage: AnalysisStage.completed,
        progress: 1.0,
      ).stageLabel, 'Completed');

      expect(AnalysisProgress(
        stage: AnalysisStage.failed,
        progress: 0.3,
        errorMessage: 'Network error',
      ).stageLabel, 'Failed');
    });

    test('should handle edge case progress values', () {
      // Test with negative progress (edge case)
      final negativeProgress = AnalysisProgress(
        stage: AnalysisStage.preprocessing,
        progress: -0.1,
      );
      // Should handle gracefully - may return null or calculated value
      expect(negativeProgress.estimatedRemaining, isA<Duration?>());

      // Test with progress > 1.0 (edge case)
      final overProgress = AnalysisProgress(
        stage: AnalysisStage.completed,
        progress: 1.5,
      );
      expect(overProgress.estimatedRemaining, isA<Duration?>());
    });

    test('should handle failed stage with error message', () {
      // Arrange & Act
      final failedProgress = AnalysisProgress(
        stage: AnalysisStage.failed,
        progress: 0.3,
        message: 'Analysis stopped',
        errorMessage: 'Unable to detect plant features',
      );

      // Assert
      expect(failedProgress.stage, AnalysisStage.failed);
      expect(failedProgress.progress, 0.3);
      expect(failedProgress.message, 'Analysis stopped');
      expect(failedProgress.errorMessage, 'Unable to detect plant features');
      expect(failedProgress.stageLabel, 'Failed');
    });

    test('should handle typical analysis workflow progression', () {
      // Test typical workflow stages with realistic progress values
      final stages = [
        AnalysisProgress(stage: AnalysisStage.preprocessing, progress: 0.0),
        AnalysisProgress(stage: AnalysisStage.preprocessing, progress: 0.2),
        AnalysisProgress(stage: AnalysisStage.detecting, progress: 0.3),
        AnalysisProgress(stage: AnalysisStage.detecting, progress: 0.7),
        AnalysisProgress(stage: AnalysisStage.postprocessing, progress: 0.8),
        AnalysisProgress(stage: AnalysisStage.postprocessing, progress: 0.95),
        AnalysisProgress(stage: AnalysisStage.completed, progress: 1.0),
      ];

      // Verify progression makes sense
      for (int i = 0; i < stages.length - 1; i++) {
        expect(stages[i].progress, lessThanOrEqualTo(stages[i + 1].progress));
      }

      // Verify final stage
      expect(stages.last.stage, AnalysisStage.completed);
      expect(stages.last.progress, 1.0);
    });

    test('should handle very small progress increments', () {
      // Test with very small progress values
      final microProgress = AnalysisProgress(
        stage: AnalysisStage.detecting,
        progress: 0.001,
      );
      
      expect(microProgress.estimatedRemaining, isA<Duration>());
      expect(microProgress.estimatedRemaining!.inSeconds, greaterThan(10));
    });

    test('should handle progress with detailed messages', () {
      // Test with realistic status messages
      final progressWithDetails = AnalysisProgress(
        stage: AnalysisStage.detecting,
        progress: 0.65,
        message: 'Analyzing leaf patterns and detecting potential diseases...',
      );

      expect(progressWithDetails.message, contains('leaf patterns'));
      expect(progressWithDetails.message, contains('diseases'));
      expect(progressWithDetails.stage, AnalysisStage.detecting);
    });
  });
}