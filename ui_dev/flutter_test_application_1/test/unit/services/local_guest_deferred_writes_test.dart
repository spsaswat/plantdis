import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/drone_batch_model.dart';
import 'package:flutter_test_application_1/models/leaf_mask.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';

const _batchesKey = 'local_guest_batches_v1';
const _analysisKey = 'macos_local_guest_analysis_v1';

DroneBatchModel _batch(String id) {
  return DroneBatchModel.fromRequest(
    BatchSegmentationRequest(
      imageId: 'img_$id',
      plantId: id,
      imageUrl: 'file:///$id.jpg',
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
      localImageBytes: Uint8List(0),
      imageWidth: 4,
      imageHeight: 4,
    ),
    userId: 'local_guest',
    createdAt: DateTime(2026, 9, 28),
  );
}

Future<String?> _stored(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

void main() {
  final guest = LocalGuestService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await guest.clearAllLocalData();
  });

  tearDown(() => guest.endDeferredWrites());

  test('holds writes in memory until flushed', () async {
    await guest.beginDeferredWrites();

    await guest.saveBatch(_batch('b1'));
    await guest.saveImageAnalysisResult(
      plantId: 'p1',
      imageId: 'i1',
      analysis: {'detectedDisease': 'x'},
    );

    expect(await _stored(_batchesKey), isNull);
    expect(await _stored(_analysisKey), isNull);
    // Reads see the pending writes.
    expect((await guest.getBatchById('b1'))?.batchId, 'b1');
    expect(
      (await guest.getLatestImageAnalysisResult(
        plantId: 'p1',
        imageId: 'i1',
      ))?['detectedDisease'],
      'x',
    );

    await guest.flushDeferredWrites();

    expect(await _stored(_batchesKey), contains('"batchId":"b1"'));
    expect(await _stored(_analysisKey), contains('p1::i1'));
  });

  test('notifies listeners on flush, not on every write', () async {
    final events = <List<DroneBatchModel>>[];
    final sub = guest.batchesStream().listen(events.add);
    await guest.beginDeferredWrites();
    // Subscribing and beginning both load the store, which announces it.
    await pumpEventQueue();
    events.clear();

    await guest.saveBatch(_batch('b1'));
    await guest.saveBatch(_batch('b2'));
    await pumpEventQueue();
    expect(events, isEmpty);

    await guest.flushDeferredWrites();
    await pumpEventQueue();
    expect(events, hasLength(1));
    expect(events.single.map((b) => b.batchId), containsAll(['b1', 'b2']));

    await sub.cancel();
  });

  test('ending writes what is pending and resumes direct writes', () async {
    await guest.beginDeferredWrites();
    await guest.saveBatch(_batch('b1'));
    await guest.endDeferredWrites();

    expect(await _stored(_batchesKey), contains('"batchId":"b1"'));

    await guest.saveBatch(_batch('b2'));
    expect(await _stored(_batchesKey), contains('"batchId":"b2"'));
  });
}
