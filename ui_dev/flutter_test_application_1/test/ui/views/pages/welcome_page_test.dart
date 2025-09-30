import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart'; 
import 'package:flutter_test_application_1/views/pages/welcome_page.dart';
import 'package:flutter_test_application_1/views/pages/login_page.dart'; 
import 'package:flutter_test_application_1/views/pages/register_page.dart'; 

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('WelcomePage renders all elements correctly', (tester) async {
    // 构建测试页面
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    
    // 验证标题显示
    expect(find.text('PlantDis'), findsOneWidget);
    
    // 验证按钮显示
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
    
    // 验证Lottie动画存在（如果实际使用了Lottie）
    // 如果你的项目中没有使用Lottie，可以删除这一行
    expect(find.byType(Lottie), findsOneWidget);
  });
  
  testWidgets('Navigate to LoginPage when Login button is pressed', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    
    // 点击登录按钮
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle(); // 等待导航完成
    
    // 验证是否导航到登录页面
    expect(find.byType(LoginPage), findsOneWidget);
  });
  
  testWidgets('Navigate to RegisterPage when Register button is pressed', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    
    // 点击注册按钮
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    
    // 验证是否导航到注册页面
    expect(find.byType(RegisterPage), findsOneWidget);
  });
  
  testWidgets('Guest sign in shows loading state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    
    // 点击游客登录按钮
    await tester.tap(find.text('Continue as Guest'));
    await tester.pump(); // 触发状态更新
    
    // 验证加载指示器显示
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
