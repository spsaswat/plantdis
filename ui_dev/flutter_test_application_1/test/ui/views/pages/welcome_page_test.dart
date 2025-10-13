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
    // Build the test page
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    
    // Verify title display
    expect(find.text('PlantDis'), findsOneWidget);
    
    // Verify button display
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
    
    // Verify Lottie animation exists (if Lottie is actually used)
    // Remove this line if your project doesn't use Lottie
    expect(find.byType(Lottie), findsOneWidget);
  });
  
  testWidgets('Navigate to LoginPage when Login button is pressed', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    
    // Tap the login button
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle(); // Wait for navigation to complete
    
    // Verify navigation to login page
    expect(find.byType(LoginPage), findsOneWidget);
  });
  
  testWidgets('Navigate to RegisterPage when Register button is pressed', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    
    // Tap the register button
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    
    // Verify navigation to register page
    expect(find.byType(RegisterPage), findsOneWidget);
  });
  
  testWidgets('Guest sign in shows loading state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    
    // Tap the guest login button
    await tester.tap(find.text('Continue as Guest'));
    await tester.pump(); // Trigger state update
    
    // Verify loading indicator display
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
