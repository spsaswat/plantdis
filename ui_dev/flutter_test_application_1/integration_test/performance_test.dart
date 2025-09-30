import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// 按你的实际项目入口修改
import 'package:flutter_test_application_1/main.dart' show MyApp;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Startup performance test', (tester) async {
    final stopwatch = Stopwatch()..start();

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;

    // 打印启动时间
    print('App startup took $elapsed ms');

    // 可选：截图
    await binding.takeScreenshot('startup_screen');

    // 基础断言：应用确实渲染出来
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
