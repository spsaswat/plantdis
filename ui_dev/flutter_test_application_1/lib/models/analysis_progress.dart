// Defines the progress of an ongoing model analysis.
// Can be consumed by UI widgets to show user-friendly status and progress bars.

enum AnalysisStage {
  preprocessing,
  detecting,
  postprocessing,
  completed,
  failed,
}

/// Simple data holder for analysis progress information.
class AnalysisProgress {
  AnalysisProgress({
    required this.stage,
    required this.progress,
    this.message,
    this.errorMessage,
  });

  /// Current stage of the analysis pipeline.
  final AnalysisStage stage;

  /// Overall progress in the range 0.0 – 1.0.
  final double progress;

  /// Optional status message to display to the user.
  final String? message;

  /// Optional error message if [stage] is [AnalysisStage.failed].
  final String? errorMessage;

  /// Estimate remaining time in seconds, derived from [progress].
  /// Returns `null` if estimation is not possible.
  Duration? get estimatedRemaining =>
      progress == 0
          ? null
          : Duration(seconds: ((1 - progress) * _total).round());

  // Heuristic total duration in seconds for estimation purposes.
  static const int _total = 12;

  /// Human-readable label for the current stage.
  String get stageLabel {
    switch (stage) {
      case AnalysisStage.preprocessing:
        return 'Preprocessing';
      case AnalysisStage.detecting:
        return 'Detecting';
      case AnalysisStage.postprocessing:
        return 'Post-processing';
      case AnalysisStage.completed:
        return 'Completed';
      case AnalysisStage.failed:
        return 'Failed';
    }
  }
}
