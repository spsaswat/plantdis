import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/data/notifiers.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';
import 'package:flutter_test_application_1/views/pages/settings_page.dart';
import 'package:flutter_test_application_1/views/pages/welcome_page.dart';
import 'package:flutter_test_application_1/views/widgets/drawer_widget.dart';

void main() {
  final launched = <String>[];
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  setUp(() {
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'launch');
          launched.add((call.arguments as Map)['url'] as String);
          return true;
        });
    LocalGuestService().setLocalGuestMode(false);
    selectedPageNotifier.value = 0;
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    LocalGuestService().setLocalGuestMode(false);
    selectedPageNotifier.value = 0;
  });

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(drawer: DrawerWidget(), body: SizedBox()),
      ),
    );
    tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  }

  testWidgets('Settings entry opens settings page', (tester) async {
    await openDrawer(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets(
    'About entry requests the project website without opening a browser',
    (tester) async {
      await openDrawer(tester);
      await tester.tap(find.widgetWithText(ListTile, 'About Us'));
      await tester.pump();
      expect(launched, ['https://plantdis.github.io/']);
    },
  );

  testWidgets('Logout clears local guest state and opens welcome', (
    tester,
  ) async {
    LocalGuestService().setLocalGuestMode(true);
    selectedPageNotifier.value = 2;
    await openDrawer(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Logout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(LocalGuestService().isLocalGuestMode(), isFalse);
    expect(selectedPageNotifier.value, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
