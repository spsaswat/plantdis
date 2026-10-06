import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test_application_1/views/pages/auto_segmentation_progress_page.dart';

void main() {
  final imageBytes = img.encodePng(img.Image(width: 64, height: 48));

  Future<ValueNotifier<AutoSegmentationStatus>> pumpPage(
    WidgetTester tester, {
    VoidCallback? onCancel,
  }) async {
    final status = ValueNotifier(
      const AutoSegmentationStatus('Loading the leaf model…'),
    );
    addTearDown(status.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AutoSegmentationProgressPage(
          imageBytes: imageBytes,
          status: status,
          onCancel: onCancel ?? () {},
        ),
      ),
    );
    return status;
  }

  testWidgets('shows the drone image behind the progress', (tester) async {
    await pumpPage(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Loading the leaf model…'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, isNull);
  });

  testWidgets('follows status updates', (tester) async {
    final status = await pumpPage(tester);

    status.value = const AutoSegmentationStatus(
      'Finding leaves… 25%',
      progress: 0.25,
    );
    await tester.pump();

    expect(find.text('Finding leaves… 25%'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.25);
  });

  testWidgets('Cancel calls back until the upload starts', (tester) async {
    var cancelled = 0;
    final status = await pumpPage(tester, onCancel: () => cancelled++);

    await tester.tap(find.text('Cancel'));
    expect(cancelled, 1);

    status.value = const AutoSegmentationStatus(
      'Uploading image…',
      cancellable: false,
    );
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    expect(cancelled, 1);
  });
}
