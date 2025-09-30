import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// 按你的实际项目入口修改
import 'package:flutter_test_application_1/main.dart' show MyApp;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App starts and shows home screen', (tester) async {
    // 启动应用
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 断言首页元素（请替换成你首页真实存在的文本/Key）
    expect(find.textContaining('PlantDis'), findsWidgets);
  });
}
