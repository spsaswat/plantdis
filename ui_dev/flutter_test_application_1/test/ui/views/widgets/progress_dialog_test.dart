import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/views/widgets/progress_dialog.dart';

void main() {
  Future<void> showIt(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder:
                              (context) =>
                                  const ProgressDialog(message: 'Working…'),
                        ),
                    child: const Text('Go'),
                  ),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    // Not pumpAndSettle: the spinner animates forever, so it never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows the message alongside a spinner', (tester) async {
    await showIt(tester);

    expect(find.text('Working…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('gives the label a Material ancestor so it picks up the theme', (
    tester,
  ) async {
    // Without one, Flutter falls back to the red-on-yellow debug text style,
    // which is what a bare Text inside showDialog used to render as.
    await showIt(tester);

    expect(
      find.ancestor(
        of: find.text('Working…'),
        matching: find.byType(Material),
      ),
      findsAtLeastNWidgets(1),
    );

    final style = tester.widget<Text>(find.text('Working…')).style!;
    expect(style.decoration ?? TextDecoration.none, TextDecoration.none);
    expect(style.color, isNot(const Color(0xFFFF0000)));
  });

  testWidgets('takes its colours from the surrounding theme', (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );
    await showIt(tester, theme: theme);

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, theme.colorScheme.surface);
    expect(
      tester.widget<Text>(find.text('Working…')).style!.color,
      theme.colorScheme.onSurface,
    );
  });

  testWidgets('cannot be dismissed out from under the caller', (tester) async {
    await showIt(tester);
    expect(find.byType(ProgressDialog), findsOneWidget);

    // A stray back/dismiss must not pop it: the caller pops it itself, and
    // would otherwise end up popping the page underneath instead.
    // maybePop reports the request as handled either way, so what matters is
    // that the route is still standing afterwards.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ProgressDialog), findsOneWidget);

    // An explicit pop, which is how the caller closes it, still works.
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ProgressDialog), findsNothing);
  });
}
