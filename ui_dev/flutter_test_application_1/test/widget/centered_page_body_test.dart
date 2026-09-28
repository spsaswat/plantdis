import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_application_1/views/widgets/centered_page_body.dart';

/// Sizes the test surface, since a plain SizedBox would just be clamped to the
/// default 800x600 and never exercise the desktop-width behaviour.
Future<void> _pumpAtWidth(
  WidgetTester tester,
  double width,
  Widget child,
) async {
  await tester.binding.setSurfaceSize(Size(width, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('CenteredPageBody', () {
    testWidgets('centres the content in a wide window', (tester) async {
      // Regression: a bare SingleChildScrollView shrink-wraps here, which
      // pinned the page to the left and left a wide empty band on the right.
      await _pumpAtWidth(
        tester,
        2000,
        const CenteredPageBody(
          children: [SizedBox(key: Key('content'), height: 40)],
        ),
      );

      final host = tester.getRect(find.byType(CenteredPageBody));
      final content = tester.getRect(find.byKey(const Key('content')));

      expect(host.width, closeTo(2000, 0.5));

      final leftGap = content.left - host.left;
      final rightGap = host.right - content.right;

      expect(leftGap, closeTo(rightGap, 1.0));
      // A left-pinned page would put the whole 1000+px gap on the right.
      expect(leftGap, greaterThan(100));
      expect(content.center.dx, closeTo(host.center.dx, 1.0));
    });

    testWidgets('caps content width above the breakpoint', (tester) async {
      await _pumpAtWidth(
        tester,
        2000,
        const CenteredPageBody(
          maxContentWidth: 900,
          children: [SizedBox(key: Key('content'), height: 40)],
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('content'))).width,
        closeTo(900, 0.5),
      );
    });

    testWidgets('uses the full width below the breakpoint', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const CenteredPageBody(
          children: [SizedBox(key: Key('content'), height: 40)],
        ),
      );

      // 400 wide minus the default 20px padding on each side.
      expect(
        tester.getSize(find.byKey(const Key('content'))).width,
        closeTo(360, 0.5),
      );
    });

    testWidgets('still scrolls when the content overflows', (tester) async {
      await _pumpAtWidth(
        tester,
        800,
        const CenteredPageBody(
          children: [SizedBox(key: Key('content'), height: 2000)],
        ),
      );

      final before = tester.getRect(find.byKey(const Key('content'))).top;
      await tester.drag(find.byType(CenteredPageBody), const Offset(0, -300));
      await tester.pump();
      final after = tester.getRect(find.byKey(const Key('content'))).top;

      expect(after, lessThan(before));
    });
  });

  group('CenteredPageBody.builder', () {
    Widget body({int itemCount = 3}) {
      return CenteredPageBody.builder(
        itemCount: itemCount,
        itemBuilder:
            (context, index) => SizedBox(key: Key('item $index'), height: 50),
        footer: const [SizedBox(key: Key('footer'), height: 30)],
        children: const [SizedBox(key: Key('header'), height: 40)],
      );
    }

    testWidgets('puts the footer after the items', (tester) async {
      await _pumpAtWidth(tester, 800, body(itemCount: 2));

      final lastItem = tester.getRect(find.byKey(const Key('item 1')));
      final footer = tester.getRect(find.byKey(const Key('footer')));

      expect(footer.top, closeTo(lastItem.bottom, 0.5));
    });

    testWidgets('centres and caps the content like the default body', (
      tester,
    ) async {
      await _pumpAtWidth(tester, 2000, body());

      final host = tester.getRect(find.byType(CenteredPageBody));
      final header = tester.getRect(find.byKey(const Key('header')));
      final item = tester.getRect(find.byKey(const Key('item 0')));

      expect(header.width, closeTo(900, 0.5));
      expect(item.width, closeTo(900, 0.5));
      expect(header.center.dx, closeTo(host.center.dx, 1.0));
      expect(item.top, closeTo(header.bottom, 0.5));
    });

    testWidgets('uses the full width below the breakpoint', (tester) async {
      await _pumpAtWidth(tester, 400, body());

      expect(
        tester.getSize(find.byKey(const Key('header'))).width,
        closeTo(360, 0.5),
      );
    });

    testWidgets('builds only the items on screen', (tester) async {
      await _pumpAtWidth(tester, 800, body(itemCount: 1000));

      expect(find.byKey(const Key('item 0')), findsOneWidget);
      expect(find.byKey(const Key('item 999')), findsNothing);

      await tester.dragUntilVisible(
        find.byKey(const Key('item 999')),
        find.byType(Scrollable),
        const Offset(0, -5000),
      );

      expect(find.byKey(const Key('item 999')), findsOneWidget);
      expect(find.byKey(const Key('item 0')), findsNothing);
    });
  });
}
