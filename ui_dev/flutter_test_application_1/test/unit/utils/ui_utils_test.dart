import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';

void main() {
  group('UIUtils', () {
    group('formatDiseaseName', () {
      test('should replace underscores with spaces', () {
        expect(UIUtils.formatDiseaseName('leaf_spot'), 'leaf spot');
        expect(
          UIUtils.formatDiseaseName('bacterial_blight'),
          'bacterial blight',
        );
        expect(
          UIUtils.formatDiseaseName('powdery_mildew_disease'),
          'powdery mildew disease',
        );
        expect(
          UIUtils.formatDiseaseName('early_late_blight'),
          'early late blight',
        );
      });

      test('should handle special cases without modification', () {
        expect(
          UIUtils.formatDiseaseName('No disease detected'),
          'No disease detected',
        );
        expect(UIUtils.formatDiseaseName('N/A'), 'N/A');
      });

      test('should handle names without underscores', () {
        expect(UIUtils.formatDiseaseName('healthy'), 'healthy');
        expect(UIUtils.formatDiseaseName('rust'), 'rust');
        expect(UIUtils.formatDiseaseName('anthracnose'), 'anthracnose');
      });

      test('should handle empty and edge cases', () {
        expect(UIUtils.formatDiseaseName(''), '');
        expect(UIUtils.formatDiseaseName('_'), ' ');
        expect(UIUtils.formatDiseaseName('__'), '  ');
        expect(UIUtils.formatDiseaseName('_disease_'), ' disease ');
      });

      test('should handle multiple consecutive underscores', () {
        expect(UIUtils.formatDiseaseName('disease__name'), 'disease  name');
        expect(
          UIUtils.formatDiseaseName('multiple___underscores'),
          'multiple   underscores',
        );
      });

      test('should handle mixed formats', () {
        expect(
          UIUtils.formatDiseaseName('Disease_Type_123'),
          'Disease Type 123',
        );
        expect(
          UIUtils.formatDiseaseName('UPPER_CASE_DISEASE'),
          'UPPER CASE DISEASE',
        );
      });

      test('should handle real disease names', () {
        // Test with actual plant disease names
        expect(
          UIUtils.formatDiseaseName('tomato_late_blight'),
          'tomato late blight',
        );
        expect(UIUtils.formatDiseaseName('apple_scab'), 'apple scab');
        expect(UIUtils.formatDiseaseName('grape_black_rot'), 'grape black rot');
        expect(
          UIUtils.formatDiseaseName('corn_northern_leaf_blight'),
          'corn northern leaf blight',
        );
      });
    });

    group('Dialog Methods', () {
      testWidgets('showLoadingDialog should display dialog with message', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => UIUtils.showLoadingDialog(
                            context,
                            'Analyzing plant...',
                          ),
                      child: Text('Show Loading'),
                    ),
              ),
            ),
          ),
        );

        // Act
        await tester.tap(find.text('Show Loading'));
        await tester.pump();
        await tester.pump();

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Analyzing plant...'), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
      });

      testWidgets('showLoadingDialog should not be dismissible', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => UIUtils.showLoadingDialog(
                            context,
                            'Processing...',
                          ),
                      child: Text('Show Loading'),
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Loading'));
        await tester.pump();
        await tester.pump();

        // Try to dismiss by tapping outside
        await tester.tapAt(Offset(50, 50)); // Tap outside dialog
        await tester.pump();

        // Dialog should still be visible
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text('Processing...'), findsOneWidget);
      });

      testWidgets('showConfirmationDialog should return true when confirmed', (
        tester,
      ) async {
        bool? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed: () async {
                        result = await UIUtils.showConfirmationDialog(
                          context: context,
                          title: 'Delete Plant',
                          message:
                              'Are you sure you want to delete this plant?',
                        );
                      },
                      child: Text('Show Confirmation'),
                    ),
              ),
            ),
          ),
        );

        // Act
        await tester.tap(find.text('Show Confirmation'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Delete Plant'), findsOneWidget);
        expect(
          find.text('Are you sure you want to delete this plant?'),
          findsOneWidget,
        );

        await tester.tap(find.text('Confirm'));
        await tester.pump();
        await tester.pump();

        // Assert
        expect(result, true);
      });

      testWidgets('showConfirmationDialog should return false when cancelled', (
        tester,
      ) async {
        bool? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed: () async {
                        result = await UIUtils.showConfirmationDialog(
                          context: context,
                          title: 'Confirm Action',
                          message: 'Continue with this action?',
                        );
                      },
                      child: Text('Show Confirmation'),
                    ),
              ),
            ),
          ),
        );

        // Act
        await tester.tap(find.text('Show Confirmation'));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump();

        // Assert
        expect(result, false);
      });

      testWidgets(
        'showConfirmationDialog should use custom button texts and colors',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder:
                      (context) => ElevatedButton(
                        onPressed:
                            () => UIUtils.showConfirmationDialog(
                              context: context,
                              title: 'Remove Plant',
                              message: 'This cannot be undone',
                              confirmText: 'Remove',
                              cancelText: 'Keep',
                              confirmColor: Colors.red,
                            ),
                        child: Text('Show Custom Dialog'),
                      ),
                ),
              ),
            ),
          );

          // Act
          await tester.tap(find.text('Show Custom Dialog'));
          await tester.pump();
          await tester.pump();

          // Assert
          expect(find.text('Remove Plant'), findsOneWidget);
          expect(find.text('This cannot be undone'), findsOneWidget);
          expect(find.text('Remove'), findsOneWidget);
          expect(find.text('Keep'), findsOneWidget);

          // Check button color
          final removeButton = tester.widget<TextButton>(
            find.ancestor(
              of: find.text('Remove'),
              matching: find.byType(TextButton),
            ),
          );
          final textChild = removeButton.child as Text;
          expect(textChild.style?.color, Colors.red);
        },
      );

      testWidgets('showConfirmationDialog should return false when dismissed', (
        tester,
      ) async {
        bool? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed: () async {
                        result = await UIUtils.showConfirmationDialog(
                          context: context,
                          title: 'Test',
                          message: 'Test message',
                        );
                      },
                      child: Text('Show Dialog'),
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump();

        // Dismiss dialog by pressing back button or escape
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/navigation',
          null,
          (data) {},
        );

        await tester.pump();

        expect(result, false);
      });
    });

    group('SnackBar Methods', () {
      testWidgets('showSnackBar should display message', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => UIUtils.showSnackBar(context, 'Test message'),
                      child: Text('Show SnackBar'),
                    ),
              ),
            ),
          ),
        );

        // Act
        await tester.tap(find.text('Show SnackBar'));
        await tester.pump();

        // Assert
        expect(find.text('Test message'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('showSnackBar should use custom colors and duration', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => UIUtils.showSnackBar(
                            context,
                            'Custom snackbar',
                            backgroundColor: Colors.purple,
                            duration: Duration(seconds: 1),
                          ),
                      child: Text('Show Custom SnackBar'),
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Custom SnackBar'));
        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, Colors.purple);
        expect(snackBar.duration, Duration(seconds: 1));
        expect(snackBar.behavior, SnackBarBehavior.floating);
      });

      testWidgets('showSuccessSnackBar should display with green background', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => UIUtils.showSuccessSnackBar(
                            context,
                            'Plant saved successfully!',
                          ),
                      child: Text('Show Success'),
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Success'));
        await tester.pump();

        expect(find.text('Plant saved successfully!'), findsOneWidget);
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, Colors.green);
      });

      testWidgets('showErrorSnackBar should display with red background', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => UIUtils.showErrorSnackBar(
                            context,
                            'Failed to analyze plant',
                          ),
                      child: Text('Show Error'),
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Error'));
        await tester.pump();

        expect(find.text('Failed to analyze plant'), findsOneWidget);
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, Colors.red);
      });
    });

    group('showDeletionDialog', () {
      testWidgets('should auto-dismiss after timeout', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => UIUtils.showDeletionDialog(
                            context,
                            'Deleting plant...',
                            timeoutSeconds: 1, // Short timeout for testing
                          ),
                      child: Text('Show Deletion Dialog'),
                    ),
              ),
            ),
          ),
        );

        // Act
        await tester.tap(find.text('Show Deletion Dialog'));
        await tester.pump();
        await tester.pump();

        // Assert dialog is shown
        expect(find.text('Deleting plant...'), findsOneWidget);
        expect(
          find.text('Deletion continuing in background...'),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Wait for auto-dismiss - use pump
        await tester.pump(Duration(seconds: 1));
        await tester.pump(Duration(milliseconds: 100));

        // Dialog should be dismissed
        expect(find.text('Deleting plant...'), findsNothing);
      });

      testWidgets('should not be manually dismissible', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => UIUtils.showDeletionDialog(
                            context,
                            'Deleting plant...',
                            timeoutSeconds: 10, // Long timeout
                          ),
                      child: Text('Show Deletion Dialog'),
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Deletion Dialog'));
        await tester.pump();
        await tester.pump();

        // Try to dismiss by tapping outside
        await tester.tapAt(Offset(50, 50));
        await tester.pump();

        // Dialog should still be visible
        expect(find.text('Deleting plant...'), findsOneWidget);
      });

      testWidgets('should display custom message', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => UIUtils.showDeletionDialog(
                            context,
                            'Removing all plant data...',
                          ),
                      child: Text('Show Custom Deletion'),
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Custom Deletion'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Removing all plant data...'), findsOneWidget);
        expect(
          find.text('Deletion continuing in background...'),
          findsOneWidget,
        );
      });
    });

    group('Real-world scenarios', () {
      testWidgets('should handle multiple snackbars in sequence', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => Column(
                      children: [
                        ElevatedButton(
                          onPressed:
                              () => UIUtils.showSuccessSnackBar(
                                context,
                                'Upload complete',
                              ),
                          child: Text('Success'),
                        ),
                        ElevatedButton(
                          onPressed:
                              () => UIUtils.showErrorSnackBar(
                                context,
                                'Analysis failed',
                              ),
                          child: Text('Error'),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        );

        // Show success snackbar
        await tester.tap(find.text('Success'));
        await tester.pump();
        expect(find.text('Upload complete'), findsOneWidget);

        // Show error snackbar (should replace the success one)
        await tester.tap(find.text('Error'));
        await tester.pump();
        expect(find.text('Analysis failed'), findsOneWidget);
        expect(find.text('Upload complete'), findsNothing);
      });

      testWidgets('should handle plant analysis workflow dialogs', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => Column(
                      children: [
                        ElevatedButton(
                          onPressed:
                              () => UIUtils.showLoadingDialog(
                                context,
                                'Uploading image...',
                              ),
                          child: Text('Upload'),
                        ),
                        ElevatedButton(
                          onPressed:
                              () => UIUtils.showConfirmationDialog(
                                context: context,
                                title: 'Start Analysis',
                                message: 'Analyze this plant for diseases?',
                              ),
                          child: Text('Analyze'),
                        ),
                        ElevatedButton(
                          onPressed:
                              () => UIUtils.showSuccessSnackBar(
                                context,
                                'Disease detected: Leaf Spot',
                              ),
                          child: Text('Result'),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        );

        // Test upload loading
        await tester.tap(find.text('Upload'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Uploading image...'), findsOneWidget);

        // Close dialog by navigation
        Navigator.of(tester.element(find.byType(Scaffold))).pop();
        await tester.pump();

        // Test analysis confirmation
        await tester.tap(find.text('Analyze'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Start Analysis'), findsOneWidget);

        await tester.tap(find.text('Confirm'));
        await tester.pump();
        await tester.pump();

        // Test result snackbar
        await tester.tap(find.text('Result'));
        await tester.pump();
        expect(find.text('Disease detected: Leaf Spot'), findsOneWidget);
      });
    });

    group('Edge cases', () {
      testWidgets('should handle empty messages gracefully', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed: () => UIUtils.showSnackBar(context, ''),
                      child: Text('Empty Message'),
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Empty Message'));
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('should handle very long messages', (tester) async {
        final longMessage =
            'This is a very long message that contains a lot of text and might need to wrap to multiple lines in the dialog or snackbar to display properly to the user.';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed:
                          () => UIUtils.showLoadingDialog(context, longMessage),
                      child: Text('Long Message'),
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Long Message'));
        await tester.pump();
        await tester.pump();

        expect(
          find.textContaining('This is a very long message'),
          findsOneWidget,
        );
      });
    });
  });
}
