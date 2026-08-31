import 'package:flutter/material.dart';

/// Opens the contextual help for drawing leaf masks.
///
/// [MaskDrawingHelpContent] is kept separate from the dialog shell so a future
/// app-wide help centre can present the same topic without duplicating it.
Future<void> showMaskDrawingHelpDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const MaskDrawingHelpDialog(),
  );
}

/// Opens the contextual help for reviewing automatically generated masks.
Future<void> showMaskReviewHelpDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const MaskReviewHelpDialog(),
  );
}

class MaskDrawingHelpDialog extends StatelessWidget {
  const MaskDrawingHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MaskHelpDialog(
      dialogKey: Key('mask-drawing-help-dialog'),
      closeButtonKey: Key('close-mask-drawing-help-button'),
      title: 'How to draw leaf masks',
      content: MaskDrawingHelpContent(),
    );
  }
}

class MaskReviewHelpDialog extends StatelessWidget {
  const MaskReviewHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MaskHelpDialog(
      dialogKey: Key('mask-review-help-dialog'),
      closeButtonKey: Key('close-mask-review-help-button'),
      title: 'How to review leaf masks',
      content: MaskReviewHelpContent(),
    );
  }
}

class _MaskHelpDialog extends StatelessWidget {
  const _MaskHelpDialog({
    required this.dialogKey,
    required this.closeButtonKey,
    required this.title,
    required this.content,
  });

  final Key dialogKey;
  final Key closeButtonKey;
  final String title;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      key: dialogKey,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: availableHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
              child: Row(
                children: [
                  Icon(Icons.help_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: theme.textTheme.headlineSmall),
                  ),
                  IconButton(
                    key: closeButtonKey,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close help',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable body for the "Drawing leaf masks" help topic.
class MaskDrawingHelpContent extends StatelessWidget {
  const MaskDrawingHelpContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Make one mask for each leaf. You only need to trace the edge — '
          'the app closes and fills the shape for you.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        const _HelpStepCard(
          step: 1,
          title: 'Trace the first leaf',
          description:
              'A blank mask is already selected. With Pen selected, drag once '
              'around the leaf and finish near where you started. The outline '
              'is closed and filled automatically.',
          illustration: _TraceLeafIllustration(),
        ),
        const SizedBox(height: 12),
        const _HelpStepCard(
          step: 2,
          title: 'Add the next leaf',
          description:
              'After finishing the first leaf, choose Add mask and trace the '
              'next one. Repeat this once for each additional leaf.',
          illustration: _AddMaskIllustration(),
        ),
        const SizedBox(height: 12),
        const _HelpStepCard(
          step: 3,
          title: 'Correct the shape',
          description:
              'Use Pen to add missing areas or Erase to remove extras.',
          illustration: _CorrectMaskIllustration(),
        ),
        const SizedBox(height: 12),
        const _HelpStepCard(
          step: 4,
          title: 'Move, check, and process',
          description:
              'Right-drag to move the image and use the mouse wheel to zoom. '
              'When every leaf has its own mask, choose Process.',
          illustration: _ProcessIllustration(),
        ),
        const SizedBox(height: 16),
        const _HelpTip(
          message: 'Made a mistake? Use Undo in the top-right corner.',
        ),
      ],
    );
  }
}

/// Reusable body for the "Reviewing automatic masks" help topic.
class MaskReviewHelpContent extends StatelessWidget {
  const MaskReviewHelpContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Check each coloured mask before processing. Select a mask to edit '
          'it, or add and remove masks when the automatic result missed a '
          'leaf or detected one incorrectly.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        const _HelpStepCard(
          step: 1,
          title: 'Select a mask',
          description:
              'Click a coloured mask on the image. The selected mask becomes '
              'stronger and its boundary appears.',
          illustration: _SelectMaskIllustration(),
        ),
        const SizedBox(height: 12),
        const _HelpStepCard(
          step: 2,
          title: 'Correct the selected mask',
          description:
              'Use Pen to draw around missing areas or Erase to draw around '
              'extra areas. Each loop is closed automatically.',
          illustration: _CorrectMaskIllustration(),
        ),
        const SizedBox(height: 12),
        const _HelpStepCard(
          step: 3,
          title: 'Handle missed or extra leaves',
          description:
              'Choose Add mask and trace a leaf that was missed. Select an '
              'unwanted mask and choose Delete selected.',
          illustration: _ManageMasksIllustration(),
        ),
        const SizedBox(height: 12),
        const _HelpStepCard(
          step: 4,
          title: 'Move, check, and process',
          description:
              'Right-drag to move the image and use the mouse wheel to zoom. '
              'When every leaf has the correct mask, choose Process.',
          illustration: _ProcessIllustration(),
        ),
        const SizedBox(height: 16),
        const _HelpTip(
          message: 'Made a mistake? Use Undo in the top-right corner.',
        ),
      ],
    );
  }
}

class _HelpTip extends StatelessWidget {
  const _HelpTip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpStepCard extends StatelessWidget {
  const _HelpStepCard({
    required this.step,
    required this.title,
    required this.description,
    required this.illustration,
  });

  final int step;
  final String title;
  final String description;
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: 'Step $step: $title. $description',
      child: Container(
        key: Key('mask-help-step-$step'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$step',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _IllustrationFrame(child: illustration),
          ],
        ),
      ),
    );
  }
}

class _IllustrationFrame extends StatelessWidget {
  const _IllustrationFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _SelectMaskIllustration extends StatelessWidget {
  const _SelectMaskIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.eco,
              size: 48,
              color: colors.tertiary.withValues(alpha: 0.38),
            ),
            const SizedBox(width: 22),
            Container(
              width: 82,
              height: 68,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                border: Border.all(color: colors.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.eco, size: 52, color: colors.tertiary),
                  Positioned(
                    right: -16,
                    bottom: -9,
                    child: Icon(
                      Icons.touch_app,
                      size: 34,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 30),
            Icon(
              Icons.eco,
              size: 42,
              color: colors.tertiary.withValues(alpha: 0.38),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageMasksIllustration extends StatelessWidget {
  const _ManageMasksIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionPreview(
              icon: Icons.add,
              label: 'Add mask',
              color: colors.primary,
            ),
            const SizedBox(width: 18),
            Text(
              'or',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 18),
            _ActionPreview(
              icon: Icons.delete_outline,
              label: 'Delete selected',
              color: colors.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPreview extends StatelessWidget {
  const _ActionPreview({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _AddMaskIllustration extends StatelessWidget {
  const _AddMaskIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, size: 52, color: colors.tertiary),
            const SizedBox(width: 24),
            Icon(Icons.arrow_forward, color: colors.onSurfaceVariant),
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: colors.primary),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 20, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Add mask',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TraceLeafIllustration extends StatelessWidget {
  const _TraceLeafIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _TraceLeafPainter(
        leafColor: colors.tertiary,
        traceColor: colors.primary,
        surfaceColor: colors.surface,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TraceLeafPainter extends CustomPainter {
  const _TraceLeafPainter({
    required this.leafColor,
    required this.traceColor,
    required this.surfaceColor,
  });

  final Color leafColor;
  final Color traceColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final leaf =
        Path()
          ..moveTo(center.dx, center.dy - 30)
          ..cubicTo(
            center.dx + 43,
            center.dy - 20,
            center.dx + 43,
            center.dy + 23,
            center.dx,
            center.dy + 30,
          )
          ..cubicTo(
            center.dx - 43,
            center.dy + 23,
            center.dx - 43,
            center.dy - 20,
            center.dx,
            center.dy - 30,
          )
          ..close();

    canvas.drawPath(leaf, Paint()..color = leafColor.withValues(alpha: 0.72));
    canvas.drawLine(
      Offset(center.dx, center.dy + 26),
      Offset(center.dx + 18, center.dy - 18),
      Paint()
        ..color = surfaceColor.withValues(alpha: 0.75)
        ..strokeWidth = 2,
    );

    final trace =
        Path()
          ..moveTo(center.dx, center.dy - 37)
          ..cubicTo(
            center.dx + 54,
            center.dy - 30,
            center.dx + 55,
            center.dy + 30,
            center.dx,
            center.dy + 38,
          )
          ..cubicTo(
            center.dx - 54,
            center.dy + 30,
            center.dx - 55,
            center.dy - 30,
            center.dx,
            center.dy - 37,
          );
    _drawDashedPath(canvas, trace, traceColor);

    canvas.drawCircle(
      Offset(center.dx + 4, center.dy - 36),
      6,
      Paint()..color = traceColor,
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Color color) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 8).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 13;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TraceLeafPainter oldDelegate) {
    return leafColor != oldDelegate.leafColor ||
        traceColor != oldDelegate.traceColor ||
        surfaceColor != oldDelegate.surfaceColor;
  }
}

class _CorrectMaskIllustration extends StatelessWidget {
  const _CorrectMaskIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CorrectionAction(
              icon: Icons.edit_outlined,
              label: 'Pen',
              explanation: 'Add missing areas',
              color: colors.primary,
            ),
            const SizedBox(width: 16),
            Text(
              'or',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            _CorrectionAction(
              icon: Icons.edit_off_outlined,
              label: 'Erase',
              explanation: 'Remove extras',
              color: colors.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectionAction extends StatelessWidget {
  const _CorrectionAction({
    required this.icon,
    required this.label,
    required this.explanation,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String explanation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 154,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            explanation,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProcessIllustration extends StatelessWidget {
  const _ProcessIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mouse_outlined,
              size: 32,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_with, size: 25, color: colors.primary),
            const SizedBox(width: 12),
            Text(
              'and',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Icon(Icons.zoom_in, size: 30, color: colors.primary),
            const SizedBox(width: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 20, color: colors.onPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Process',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
