// test/helpers/test_helpers.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 提供登录/注册页面测试所需的便捷方法
class TestHelpers {
  /// 初始化测试环境（用于需要 Firebase 绑定或 Widgets 绑定的场景）
  static Future<void> setupFirebaseMocks() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  /// 用 MaterialApp 包裹被测页面
  static Widget createTestApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  /// 将被测页面装载到测试环境中并完成一次结算
  static Future<void> pumpWithSetup(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(createTestApp(child));
    await tester.pump();
  }
}
