import 'package:flutter/material.dart';

/// A scrollable page body that stays centred and capped in width.
///
/// The outer [Center] is load-bearing. A bare [SingleChildScrollView] receives
/// loose cross-axis constraints here and shrink-wraps to its child, so anything
/// narrower than the window ends up pinned to the left edge with a wide empty
/// band down the right-hand side on desktop. Wrapping it in [Center] makes the
/// scroll view sit in the middle of whatever width it takes.
class CenteredPageBody extends StatelessWidget {
  const CenteredPageBody({
    required this.children,
    this.maxContentWidth = 900,
    this.wideBreakpoint = 500,
    this.padding = const EdgeInsets.all(20.0),
    super.key,
  });

  final List<Widget> children;

  /// Width cap applied once the viewport is wider than [wideBreakpoint].
  final double maxContentWidth;
  final double wideBreakpoint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    constraints.maxWidth > wideBreakpoint
                        ? maxContentWidth
                        : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            );
          },
        ),
      ),
    );
  }
}
