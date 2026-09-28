import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/drone_batch_model.dart';
import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/services/batch_processing_service.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';

void main() {
  final guest = LocalGuestService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    guest.setLocalGuestMode(true);
    await guest.clearAllLocalData();
  });

  tearDown(() => guest.setLocalGuestMode(false));

  test('the batch is on disk before the closing event is emitted', () async {
    // Bytes that are not an image, so the run stops before any model is
    // needed and finalizes the batch as failed.
    final request = BatchSegmentationRequest(
      imageId: 'img_drone',
      plantId: 'drone_1',
      imageUrl: '',
      labels: const [NormalizedLabelRect(x: 0, y: 0, width: 0.5, height: 0.5)],
      masks: [
        LeafMask(
          left: 0,
          top: 0,
          width: 2,
          height: 2,
          bytes: Uint8List(4)..fillRange(0, 4, 1),
        ),
      ],
      source: SegmentationSource.sam,
      localImageBytes: Uint8List.fromList([1, 2, 3]),
      imageWidth: 4,
      imageHeight: 4,
    );

    final runner = BatchProcessingRunner();
    final prefs = await SharedPreferences.getInstance();
    String? storedWhenDone;
    runner.progress.listen((p) {
      // Read without awaiting, so a write still in flight cannot finish first.
      if (p.done) storedWhenDone = prefs.getString('local_guest_batches_v1');
    });

    final batch = await runner.run(request);
    await pumpEventQueue();

    expect(batch.status, BatchStatus.error);
    // The result page reads the batch back as soon as it sees this event, so
    // the failed status must already be written, not held in memory.
    expect(storedWhenDone, contains('"status":"${BatchStatus.error}"'));
    runner.dispose();
  });
}
