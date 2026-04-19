import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';

class LocalGuestService {
  static const String _guestModeKey = 'macos_local_guest_mode';
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
    final file = io.File('${io.Directory.systemTemp.path}/$imageId.jpg');
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
    final next = _plantsNotifier.value
        .where((p) => p.plantId != plantId)
        .toList(growable: false);
    _plantsNotifier.value = next;
    _plantsController.add(next);
    await _persistPlants(next);
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
