import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/models/drone_batch_model.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/utils/logger.dart';

/// Reads and writes [DroneBatchModel] records.
///
/// Follows the same dual-backend split as [PlantService]: Firestore under
/// `droneBatches/{batchId}` when signed in, SharedPreferences via
/// [LocalGuestService] in local-guest mode.
class DroneBatchService {
  FirebaseAuth? _authInstance;
  FirebaseFirestore? _firestoreInstance;

  FirebaseAuth get _auth => _authInstance ??= FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  final LocalGuestService _localGuestService = LocalGuestService();
  final PlantService _plantService = PlantService();

  CollectionReference<Map<String, dynamic>> get _batches =>
      _firestore.collection('droneBatches');

  bool get _isGuest => _localGuestService.isLocalGuestMode();

  /// Owner id for a new batch: the Firebase uid, or the guest sentinel.
  String get currentUserId {
    if (_isGuest) return 'local_guest';
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.uid;
  }

  /// Creates the initial record with one pending entry per label.
  Future<DroneBatchModel> createFromRequest(
    BatchSegmentationRequest request,
  ) async {
    final batch = DroneBatchModel.fromRequest(
      request,
      userId: currentUserId,
    );
    await save(batch);
    return batch;
  }

  Future<void> save(DroneBatchModel batch) async {
    final next = batch.copyWith(updatedAt: DateTime.now());
    if (_isGuest) {
      await _localGuestService.saveBatch(next);
      return;
    }
    await _batches.doc(next.batchId).set(next.toMap(), SetOptions(merge: true));
  }

  /// Writes [entry] back into the batch and returns the updated record.
  Future<DroneBatchModel?> upsertLeafEntry(
    String batchId,
    BatchLeafEntry entry,
  ) async {
    final current = await getBatch(batchId);
    if (current == null) return null;
    final next = current.withLeaf(entry);
    await save(next);
    return next;
  }

  Future<DroneBatchModel> finalizeBatch(
    DroneBatchModel batch, {
    required String status,
    BatchSummary? summary,
    String? errorMessage,
  }) async {
    final next = batch.copyWith(
      status: status,
      summary: summary,
      errorMessage: errorMessage,
      updatedAt: DateTime.now(),
    );
    await save(next);
    return next;
  }

  Future<DroneBatchModel?> getBatch(String batchId) async {
    if (_isGuest) return _localGuestService.getBatchById(batchId);
    final snap = await _batches.doc(batchId).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return DroneBatchModel.fromMap(data);
  }

  Stream<DroneBatchModel?> batchStream(String batchId) {
    if (_isGuest) return _localGuestService.batchStreamForBatchId(batchId);
    return _batches.doc(batchId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return DroneBatchModel.fromMap(data);
    });
  }

  /// All batches for the current user, newest first.
  ///
  /// Falls back to an unordered query when the composite index is missing, the
  /// same way [PlantService.userPlantsStream] does.
  Stream<List<DroneBatchModel>> userBatchesStream() {
    if (_isGuest) return _localGuestService.batchesStream();

    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(Exception('User not authenticated'));
    }

    final controller = StreamController<List<DroneBatchModel>>.broadcast();
    void fetch(bool withOrderBy) {
      Query<Map<String, dynamic>> query = _batches.where(
        'userId',
        isEqualTo: user.uid,
      );
      if (withOrderBy) {
        query = query.orderBy('createdAt', descending: true);
      }
      query.snapshots().listen(
        (snapshot) {
          final list =
              snapshot.docs
                  .map((doc) => DroneBatchModel.fromMap(doc.data()))
                  .toList();
          if (!withOrderBy) {
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
          if (!controller.isClosed) controller.add(list);
        },
        onError: (Object error) {
          final missingIndex =
              error.toString().contains('failed-precondition') ||
              error.toString().contains('requires an index');
          if (withOrderBy && missingIndex) {
            if (kDebugMode) {
              logger.w(
                '[DroneBatchService] Index missing, retrying without orderBy: $error',
              );
            }
            fetch(false);
            return;
          }
          logger.e('[DroneBatchService] userBatchesStream error: $error');
          if (!controller.isClosed) controller.addError(error);
        },
      );
    }

    fetch(true);
    return controller.stream;
  }

  /// Deletes the batch record and, by default, the plants it created — both the
  /// per-leaf children and the parent drone plant.
  Future<void> deleteBatch(
    String batchId, {
    bool deleteLeafPlants = true,
    bool deleteParentPlant = true,
  }) async {
    final batch = await getBatch(batchId);

    if (batch != null && deleteLeafPlants) {
      for (final leaf in batch.leaves) {
        final leafPlantId = leaf.leafPlantId;
        if (leafPlantId == null) continue;
        try {
          await _plantService.deletePlant(leafPlantId);
        } catch (e) {
          // Keep deleting the rest; a missing child should not block cleanup.
          logger.w('[DroneBatchService] Could not delete leaf $leafPlantId: $e');
        }
      }
    }

    if (_isGuest) {
      await _localGuestService.deleteBatch(batchId);
    } else {
      await _batches.doc(batchId).delete();
    }

    if (batch != null && deleteParentPlant) {
      try {
        await _plantService.deletePlant(batch.parentPlantId);
      } catch (e) {
        logger.w(
          '[DroneBatchService] Could not delete parent plant '
          '${batch.parentPlantId}: $e',
        );
      }
    }
  }
}
