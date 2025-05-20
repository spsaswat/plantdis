import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/analysis_progress.dart';

/// Animated widget that visualises [AnalysisProgress] with a circular
/// progress indicator, current step label, and an optional ETA.
class AnalysisProgressWidget extends StatelessWidget {
  const AnalysisProgressWidget({super.key, required this.progress});

  final AnalysisProgress progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress.progress),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          builder:
              (context, value, child) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 8,
                      color: colorScheme.primary,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    '${(value * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
        ),
        const SizedBox(height: 12),
        Text(progress.stageLabel, style: Theme.of(context).textTheme.bodyLarge),
        if (progress.estimatedRemaining != null) ...[
          const SizedBox(height: 4),
          Text(
            '~${progress.estimatedRemaining!.inSeconds}s remaining',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
        ],
      ],
    );
  }
}
