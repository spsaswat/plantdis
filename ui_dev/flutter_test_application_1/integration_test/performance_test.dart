import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import your actual app entry point.
// Adjust if your main.dart exports a different root widget.
import 'package:flutter_test_application_1/main.dart' show MyApp;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Startup performance & first frame stability', (tester) async {
    // 1) Measure cold start duration until the first frame is stable
    final sw = Stopwatch()..start();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));
    sw.stop();
    final startupMs = sw.elapsedMilliseconds;

    // 2) Basic visibility check: the app should render a MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);

    // 3) Take a screenshot of the first screen (optional)
    await binding.takeScreenshot('perf_01_home');

    // 4) Try to record a short performance trace of a light interaction
    //    `watchPerformance` may not exist in all integration_test versions.
    //    If not supported, the try/catch will silently ignore it.
    try {
      await binding.watchPerformance(() async {
        // Example interaction: drag a scrollable widget if available
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
        } else {
          // If no scrollable is found, trigger a simple repaint
          await tester.pump(const Duration(milliseconds: 16));
        }
      }, reportKey: 'scroll_trace');
    } catch (_) {
      // Ignore if `watchPerformance` is not available
    }

    // 5) Report structured metrics
    //    These will be collected in CI (flutter drive) or printed locally.
    binding.reportData = <String, dynamic>{
      'startup_ms': startupMs,
      // If watchPerformance succeeded, its data will also be included.
    };

    // 6) Print friendly output for local debugging
    // ignore: avoid_print
    print('App startup took ${startupMs} ms');
  });
}
