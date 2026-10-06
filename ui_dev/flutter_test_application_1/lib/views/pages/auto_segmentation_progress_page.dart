import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// What [AutoSegmentationProgressPage] shows.
class AutoSegmentationStatus {
  const AutoSegmentationStatus(
    this.message, {
    this.progress,
    this.cancellable = true,
  });

  final String message;

  /// 0–1, or null while the amount of work is not known yet.
  final double? progress;

  /// False once the upload starts, which cannot be undone half-way.
  final bool cancellable;
}

/// Shows the drone image while automatic segmentation runs, so the user is
/// not left looking at an empty screen for minutes.
///
/// The caller drives [status] and replaces or pops this route when done.
class AutoSegmentationProgressPage extends StatelessWidget {
  const AutoSegmentationProgressPage({
    required this.imageBytes,
    required this.status,
    required this.onCancel,
    super.key,
  });

  final Uint8List imageBytes;
  final ValueListenable<AutoSegmentationStatus> status;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // Leaving goes through Cancel, which also stops the background work.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Automatic segmentation'),
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                label: 'Drone image being segmented',
                image: true,
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  // A 20 MP frame decoded at full size only costs memory here.
                  cacheWidth: 2048,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                      child: ValueListenableBuilder(
                        valueListenable: status,
                        builder:
                            (context, value, _) => Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    value.message,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: LinearProgressIndicator(
                                    value: value.progress,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed:
                                        value.cancellable ? onCancel : null,
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
