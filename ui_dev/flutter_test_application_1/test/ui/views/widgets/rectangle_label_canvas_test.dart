import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/views/widgets/rectangle_label_canvas.dart';

Uint8List _testPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  testWidgets('creates a normalized label for a completed drag', (
    tester,
  ) async {
    final labels = <NormalizedLabelRect>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: RectangleLabelCanvas(
                imageBytes: _testPng(),
                imageAspectRatio: 1,
                labels: const [],
                onLabelCreated: labels.add,
              ),
            ),
          ),
        ),
      ),
    );

    final gestureArea = find.byKey(const Key('rectangle-label-gesture-area'));
    final topLeft = tester.getTopLeft(gestureArea);
    await tester.dragFrom(
      topLeft + const Offset(30, 60),
      const Offset(150, 120),
    );
    await tester.pump();

    expect(labels, hasLength(1));
    expect(labels.single.x, closeTo(0.1, 0.01));
    expect(labels.single.y, closeTo(0.2, 0.01));
    expect(labels.single.width, closeTo(0.5, 0.01));
    expect(labels.single.height, closeTo(0.4, 0.01));
  });

  testWidgets('ignores a tiny accidental drag', (tester) async {
    final labels = <NormalizedLabelRect>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 300,
          child: RectangleLabelCanvas(
            imageBytes: _testPng(),
            imageAspectRatio: 1,
            labels: const [],
            onLabelCreated: labels.add,
          ),
        ),
      ),
    );

    final topLeft = tester.getTopLeft(
      find.byKey(const Key('rectangle-label-gesture-area')),
    );
    await tester.dragFrom(topLeft + const Offset(50, 50), const Offset(1, 1));

    expect(labels, isEmpty);
  });
}
