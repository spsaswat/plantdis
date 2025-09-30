import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/pages/register_page.dart';
import '../../../helpers/test_helpers.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('RegisterPage renders all elements correctly', (tester) async {
    await tester.pumpWidget(TestHelpers.createTestApp(const RegisterPage()));
    
    // 验证标题显示
    expect(find.text('Register'), findsOneWidget);
    
    // 验证输入框显示
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Username / Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    
    // 验证按钮显示
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
  });
  
  testWidgets('Shows error when fields are empty', (tester) async {
    await tester.pumpWidget(TestHelpers.createTestApp(const RegisterPage()));
    
    // 点击注册按钮（不输入任何内容）
    await tester.tap(find.text('Register'));
    await tester.pump();
    
    // 验证错误信息显示
    expect(find.text('Please fill in all fields'), findsOneWidget);
  });
  
  testWidgets('Shows error when passwords do not match', (tester) async {
    await tester.pumpWidget(TestHelpers.createTestApp(const RegisterPage()));
    
    // 输入邮箱
    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    // 输入密码
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    // 输入不匹配的确认密码
    await tester.enterText(find.byType(TextField).at(2), 'password124');
    
    // 点击注册按钮
    await tester.tap(find.text('Register'));
    await tester.pump();
    
    // 验证错误信息显示
    expect(find.text('Passwords do not match'), findsOneWidget);
  });
  
  testWidgets('Shows loading state when registering', (tester) async {
    await tester.pumpWidget(TestHelpers.createTestApp(const RegisterPage()));
    
    // 输入测试数据
    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    
    // 点击注册按钮
    await tester.tap(find.text('Register'));
    await tester.pump();
    
    // 验证加载指示器显示
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
