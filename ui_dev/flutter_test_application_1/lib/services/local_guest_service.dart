import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:flutter_test_application_1/utils/logger.dart';
import 'package:flutter_test_application_1/utils/storage_utils.dart';

class LocalGuestService {
  LocalGuestService._();
  /// Single instance so all screens share the same plant stream/notifier and prefs stay in sync.
  static final LocalGuestService _instance = LocalGuestService._();
  factory LocalGuestService() => _instance;

  static const String _plantsKey = 'macos_local_guest_plants_v1';
  static const String _analysisKey = 'macos_local_guest_analysis_v1';
  static bool localGuestMode = false;

  final ValueNotifier<List<PlantModel>> _plantsNotifier =
      ValueNotifier<List<PlantModel>>(<PlantModel>[]);
  final StreamController<List<PlantModel>> _plantsController =
      StreamController<List<PlantModel>>.broadcast();

  static bool get isMacOS => !kIsWeb && io.Platform.isMacOS;
  static bool get isDesktopApp => io.Platform.isMacOS || io.Platform.isWindows || io.Platform.isLinux;

  bool isLocalGuestMode() {
    return localGuestMode;
  }

  void setLocalGuestMode(bool enabled) {
    localGuestMode = enabled;
  }

  /// One plant, or `null` if missing — mirrors a single Firestore plant doc stream.
  Stream<PlantModel?> plantStreamForPlantId(String plantId) {
    return plantsStream().map((plants) {
      try {
        return plants.firstWhere((p) => p.plantId == plantId);
      } catch (_) {
        return null;
      }
    });
  }

  /// Merge keys into [analysisResults], optionally set [status].
  Future<void> mergeAnalysisResultsIntoPlant({
    required String plantId,
    required Map<String, dynamic> patch,
    String? status,
  }) async {
    final current = await getPlantById(plantId);
    if (current == null) return;
    final merged = <String, dynamic>{
      ...?current.analysisResults,
      ...patch,
    };
    await updatePlant(
      plantId: plantId,
      status: status,
      analysisResults: merged,
    );
  }

  /// Firestore-style map keys like `analysisResults.segmentationUrl` → flat merge into analysisResults.
  Future<void> applyNestedAnalysisResultUpdates({
    required String plantId,
    required Map<String, Object?> updates,
  }) async {
    final current = await getPlantById(plantId);
    final merged = <String, dynamic>{...?current?.analysisResults};
    for (final e in updates.entries) {
      final key = e.key;
      final value = e.value;
      if (key.startsWith('analysisResults.')) {
        merged[key.replaceFirst('analysisResults.', '')] = value;
      } else {
        merged[key] = value;
      }
    }
    await updatePlant(plantId: plantId, analysisResults: merged);
  }

  Future<void> markPlantAnalysisError(String plantId, String message) async {
    await mergeAnalysisResultsIntoPlant(
      plantId: plantId,
      status: 'error',
      patch: {
        'analysisError': message,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Target file for segmentation mask (Firebase Storage–style path under Application Support).
  /// Returns `null` when not in guest mode or when the mirror path cannot be resolved.
  Future<io.File?> segmentationOutputFileForWrite({
    required String plantId,
    required String imageId,
  }) async {
    if (!isLocalGuestMode()) return null;
    try {
      final base = await getApplicationSupportDirectory();
      final plant = await getPlantById(plantId);
      final userId = plant?.userId ?? 'local_guest';
      final file = StorageUtils.localProcessedImageFile(
        base,
        userId,
        plantId,
        imageId,
        'segmentation',
        'png',
      );
      file.parent.createSync(recursive: true);
      return file;
    } catch (e, st) {
      logger.w(
        '[LocalGuestService] Segmentation mirror path failed, will use temp: $e\n$st',
      );
      return null;
    }
  }

  /// URI stored in analysis / prefs: always the mirror path; copies [segmentedFile] if needed.
  Future<String> persistSegmentationLocalUri(
    io.File segmentedFile, {
    required String plantId,
    required String imageId,
  }) async {
    final mirror = await segmentationOutputFileForWrite(
      plantId: plantId,
      imageId: imageId,
    );
    if (mirror == null) {
      return segmentedFile.uri.toString();
    }
    if (segmentedFile.path != mirror.path) {
      mirror.parent.createSync(recursive: true);
      await segmentedFile.copy(mirror.path);
    }
    return mirror.uri.toString();
  }

  Stream<List<PlantModel>> plantsStream() async* {
    await _reloadPlants();
    yield _plantsNotifier.value;
    yield* _plantsController.stream;
  }

  Future<List<PlantModel>> getPlants() async {
    await _reloadPlants();
    return _plantsNotifier.value;
  }

  Future<Map<String, dynamic>> createLocalPlantFromImage({
    required Uint8List imageBytes,
  }) async {
    final now = DateTime.now();
    final plantId = 'local_plant_${now.microsecondsSinceEpoch}';
    final imageId = 'local_img_${now.microsecondsSinceEpoch}';
    // Persist under Application Support (system temp is cleared and breaks FileImage on restart).
    final support = await getApplicationSupportDirectory();
    final dir = io.Directory(
      p.join(support.path, 'local_guest', 'images'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final path = p.join(dir.path, '$imageId.jpg');
    final file = io.File(path);
    await file.writeAsBytes(imageBytes, flush: true);

    final plant = PlantModel(
      plantId: plantId,
      userId: 'local_guest',
      createdAt: now,
      status: 'pending',
      images: <String>[imageId],
      analysisResults: <String, dynamic>{
        'localImagePath': file.path,
      },
    );
    await _savePlant(plant);
    return <String, dynamic>{
      'plantId': plantId,
      'imageId': imageId,
      'downloadUrl': file.uri.toString(),
    };
  }

  Future<PlantModel?> getPlantById(String plantId) async {
    await _reloadPlants();
    for (final plant in _plantsNotifier.value) {
      if (plant.plantId == plantId) return plant;
    }
    return null;
  }

  Future<void> updatePlant({
    required String plantId,
    String? status,
    Map<String, dynamic>? analysisResults,
  }) async {
    await _reloadPlants();
    final next = <PlantModel>[];
    for (final p in _plantsNotifier.value) {
      if (p.plantId == plantId) {
        next.add(
          p.copyWith(
            status: status ?? p.status,
            updatedAt: DateTime.now(),
            analysisResults: analysisResults ?? p.analysisResults,
          ),
        );
      } else {
        next.add(p);
      }
    }
    _plantsNotifier.value = next;
    _plantsController.add(next);
    await _persistPlants(next);
  }

  Future<void> saveImageAnalysisResult({
    required String plantId,
    required String imageId,
    required Map<String, dynamic> analysis,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_analysisKey);
    final map = raw == null
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map<String, dynamic>);
    map['$plantId::$imageId'] = <String, dynamic>{
      ...analysis,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_analysisKey, jsonEncode(map));
  }

  Future<Map<String, dynamic>?> getLatestImageAnalysisResult({
    required String plantId,
    required String imageId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_analysisKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final data = map['$plantId::$imageId'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<void> deletePlant(String plantId) async {
    await _reloadPlants();
    PlantModel? removed;
    for (final p in _plantsNotifier.value) {
      if (p.plantId == plantId) {
        removed = p;
        break;
      }
    }
    final next = _plantsNotifier.value
        .where((p) => p.plantId != plantId)
        .toList(growable: false);
    _plantsNotifier.value = next;
    _plantsController.add(next);
    await _persistPlants(next);

    if (removed != null) {
      await _deleteGuestOriginalImage(removed);
      await _deleteLocalStorageMirrorForPlant(removed.userId, plantId);
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_analysisKey);
    if (raw != null && raw.isNotEmpty) {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      map.removeWhere((k, _) => k.startsWith('$plantId::'));
      await prefs.setString(_analysisKey, jsonEncode(map));
    }
  }

  Future<void> clearAllLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_plantsKey);
    await prefs.remove(_analysisKey);
    _plantsNotifier.value = <PlantModel>[];
    _plantsController.add(const <PlantModel>[]);
  }

  Future<void> _savePlant(PlantModel plant) async {
    await _reloadPlants();
    final next = <PlantModel>[plant, ..._plantsNotifier.value];
    _plantsNotifier.value = next;
    _plantsController.add(next);
    await _persistPlants(next);
  }

  Future<void> _reloadPlants() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plantsKey);
    if (raw == null || raw.isEmpty) {
      _plantsNotifier.value = <PlantModel>[];
      _plantsController.add(const <PlantModel>[]);
      return;
    }
    final arr = jsonDecode(raw) as List<dynamic>;
    final plants = arr.map((e) {
      final m = e as Map<String, dynamic>;
      return PlantModel(
        plantId: m['plantId'] as String,
        userId: m['userId'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: m['updatedAt'] == null
            ? null
            : DateTime.parse(m['updatedAt'] as String),
        status: m['status'] as String,
        images: (m['images'] as List<dynamic>).cast<String>(),
        analysisResults:
            (m['analysisResults'] as Map?)?.cast<String, dynamic>(),
      );
    }).toList(growable: false);
    _plantsNotifier.value = plants;
    _plantsController.add(plants);
  }

  /// Deletes the on-disk file referenced by [analysisResults.localImagePath] (if any).
  Future<void> _deleteGuestOriginalImage(PlantModel plant) async {
    if (kIsWeb) return;
    try {
      final pth = plant.analysisResults?['localImagePath'] as String?;
      if (pth == null || pth.isEmpty) return;
      final f = io.File(pth);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (e, st) {
      logger.w(
        '[LocalGuestService] Could not delete guest image file: $e\n$st',
      );
    }
  }

  /// Removes mirrored files under Application Support (same layout as Firebase).
  Future<void> _deleteLocalStorageMirrorForPlant(
    String userId,
    String plantId,
  ) async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final root = io.Directory(
        p.join(
          dir.path,
          StorageUtils.localStorageMirrorRoot,
          'users',
          userId,
          'plants',
          plantId,
        ),
      );
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> _persistPlants(List<PlantModel> plants) async {
    final prefs = await SharedPreferences.getInstance();
    final arr = plants
        .map((p) => <String, dynamic>{
              'plantId': p.plantId,
              'userId': p.userId,
              'createdAt': p.createdAt.toIso8601String(),
              'updatedAt': p.updatedAt?.toIso8601String(),
              'status': p.status,
              'images': p.images,
              'analysisResults': p.analysisResults,
            })
        .toList(growable: false);
    await prefs.setString(_plantsKey, jsonEncode(arr));
  }
}
