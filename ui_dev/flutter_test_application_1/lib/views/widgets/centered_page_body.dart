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
  }) : itemCount = 0,
       itemBuilder = null,
       footer = const [];

  /// [children], then [itemCount] items built on demand, then [footer].
  ///
  /// For pages with a long list between fixed content: only what is on
  /// screen is built and laid out, where the default constructor lays out
  /// every child on every rebuild. Unlike the default constructor, content
  /// shorter than the window sits at the top rather than centred vertically.
  const CenteredPageBody.builder({
    required this.children,
    required this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.footer = const [],
    this.maxContentWidth = 900,
    this.wideBreakpoint = 500,
    this.padding = const EdgeInsets.all(20.0),
    super.key,
  });

  final List<Widget> children;
  final int itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final List<Widget> footer;

  /// Width cap applied once the viewport is wider than [wideBreakpoint].
  final double maxContentWidth;
  final double wideBreakpoint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final itemBuilder = this.itemBuilder;
    if (itemBuilder != null) {
      return Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Same cap as below, measured inside the padding like it is there.
            final inner = constraints.maxWidth - padding.horizontal;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    inner > wideBreakpoint
                        ? maxContentWidth + padding.horizontal
                        : double.infinity,
              ),
              child: ListView.builder(
                padding: padding,
                itemCount: children.length + itemCount + footer.length,
                itemBuilder: (context, index) {
                  if (index < children.length) return children[index];
                  index -= children.length;
                  if (index < itemCount) return itemBuilder(context, index);
                  return footer[index - itemCount];
                },
              ),
            );
          },
        ),
      );
    }

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
