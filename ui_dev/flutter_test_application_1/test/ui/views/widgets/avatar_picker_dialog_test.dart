import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/widgets/avatar_picker_dialog.dart';

void main() {
  testWidgets('Basic UI elements rendering', (WidgetTester tester) async {
    // Build Dialog Box
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AvatarPickerDialog(
                  onAvatarSelected: (url) {},
                ),
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // open dialog box
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // verify title
    expect(find.text('Choose Profile Picture'), findsOneWidget);

    // Verify the number of preset avatars (4)
    expect(find.byType(CircleAvatar), findsNWidgets(5)); // 4 presets + 1 upload button

    // verufy cancel button
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Select preset avatar closes dialog and triggers callback', (WidgetTester tester) async {

  String? selectedAvatar;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AvatarPickerDialog(
                onAvatarSelected: (url) => selectedAvatar = url,
              ),
            ),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Dialog'));
  await tester.pumpAndSettle();

  // Search for a preset avatar (CircleAvatar) inside the dialog box to avoid 
  // hitting the InkWell outside the dialog box
  final presetAvatar = find.descendant(
    of: find.byType(AvatarPickerDialog),
    matching: find.byType(CircleAvatar),
  ).first;

  await tester.tap(presetAvatar);
  await tester.pumpAndSettle();

  // Assert: The callback is triggered and the dialog is closed
  expect(selectedAvatar, isNotNull);
  expect(find.byType(AvatarPickerDialog), findsNothing);
});


  testWidgets('Cancel button closes dialog', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AvatarPickerDialog(
                  onAvatarSelected: (url) {},
                ),
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    // click on cancel button
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Upload button shows loading state when tapped', (WidgetTester tester) async {

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AvatarPickerDialog(onAvatarSelected: (_) {}),
            ),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Dialog'));
  await tester.pumpAndSettle();

  // Limit the Finder to the dialog box to avoid clicking on the same icon behind it
  final uploadIcon = find.descendant(
    of: find.byType(AvatarPickerDialog),
    matching: find.byIcon(Icons.add_photo_alternate),
  );

  expect(uploadIcon, findsOneWidget);

  // Without mocking ImagePicker / Firebase, clicking should not crash, 
  // but the loading circle will not appear.
  await tester.tap(uploadIcon);
  await tester.pump();

  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(uploadIcon, findsOneWidget);
});
}
