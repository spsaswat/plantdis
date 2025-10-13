import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/pages/register_page.dart';
import '../../../helpers/test_helpers.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('RegisterPage renders all elements correctly', (tester) async {
    await tester.pumpWidget(TestHelpers.createTestApp(const RegisterPage()));
    
    // Verify title display
    expect(find.text('Register'), findsOneWidget);
    
    // Verify input box display
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Username / Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    
    // Verify button display
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
  });
  
  testWidgets('Shows error when fields are empty', (tester) async {
    await tester.pumpWidget(TestHelpers.createTestApp(const RegisterPage()));
    
    // Click the Register button (do not enter anything)
    await tester.tap(find.text('Register'));
    await tester.pump();
    
    // Validation error message display
    expect(find.text('Please fill in all fields'), findsOneWidget);
  });
  
  testWidgets('Shows error when passwords do not match', (tester) async {
    await tester.pumpWidget(TestHelpers.createTestApp(const RegisterPage()));
    
    // Enter your email address
    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    // Enter password
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    // Enter a mismatched confirmation password
    await tester.enterText(find.byType(TextField).at(2), 'password124');
    
    // Click the Register button
    await tester.tap(find.text('Register'));
    await tester.pump();
    
    // Validation error message display
    expect(find.text('Passwords do not match'), findsOneWidget);
  });
  
  testWidgets('Shows loading state when registering', (tester) async {
    await tester.pumpWidget(TestHelpers.createTestApp(const RegisterPage()));
    
    // Enter test data
    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    
    // Click the Register button
    await tester.tap(find.text('Register'));
    await tester.pump();
    
    // Verify that the loading indicator appears
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
