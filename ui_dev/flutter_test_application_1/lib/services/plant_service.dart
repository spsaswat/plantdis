import 'dart:async';
// For Uint8List
import 'dart:io' as io; // For File operations on mobile, conditionally used

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb, kDebugMode
import 'package:image/image.dart' as img;
import 'package:flutter_test_application_1/services/tflite_interop/tflite_wrapper.dart';

import '../models/plant_model.dart';
import '../models/image_model.dart';
import '../models/detection_result.dart';
import '../utils/storage_utils.dart';
import '../utils/logger.dart';
import './inference_service.dart';
import './segmentation_service.dart';
// import 'package:flutter/material.dart'; // Removed as it did not seem directly used by PlantService logic

class PlantService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InferenceService _inferenceService = InferenceService();
  final SegmentationService _segmentationService = SegmentationService();

  CollectionReference get _plants => _firestore.collection('plants');
  CollectionReference get _images => _firestore.collection('images');
  CollectionReference get _users => _firestore.collection('users');

  Future<Map<String, dynamic>> uploadAndAnalyzeImage({
    required XFile image,
    String? notes,
    String? existingPlantId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final String plantId = existingPlantId ?? StorageUtils.generatePlantId();
    final String imageId = StorageUtils.generateImageId();
    final Uint8List imageBytes = await image.readAsBytes();
    final String imageName = image.name;

    String extension;
    if (kIsWeb) {
      final mimeType = image.mimeType;
      if (mimeType == 'image/png') {
        extension = 'png';
      } else if (mimeType == 'image/jpeg') {
        extension = 'jpg';
      } else {
        extension = imageName.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          throw Exception(
            'Invalid image format on web. Supported: jpg, jpeg, png. Got: $mimeType',
          );
        }
      }
    } else {
      extension = StorageUtils.getFileExtension(image.path);
      if (!StorageUtils.isValidImageExtension(extension)) {
        throw Exception(
          'Invalid image format on mobile. Supported: jpg, jpeg, png',
        );
      }
    }
    String contentType = StorageUtils.getContentType(extension);
    String storagePath = StorageUtils.getOriginalImagePath(
      user.uid,
      plantId,
      imageId,
      extension,
    );
    Reference storageRef = _storage.ref().child(storagePath);

    if (kDebugMode) {
      logger.i('[PlantService] Uploading image bytes to $storagePath...');
    }
    UploadTask uploadTask = storageRef.putData(
      imageBytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'plantId': plantId,
          'imageId': imageId,
          'userId': user.uid,
          'uploadTime': DateTime.now().toIso8601String(),
          'originalName': imageName,
        },
      ),
    );
    TaskSnapshot taskSnapshot = await uploadTask;
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();
    if (kDebugMode) logger.i('[PlantService] Image uploaded to $downloadUrl');

    ImageModel imageModel = ImageModel(
      imageId: imageId,
      plantId: plantId,
      userId: user.uid,
      originalUrl: downloadUrl,
      processedUrls: {},
      uploadTime: DateTime.now(),
      metadata: {
        'notes': notes,
        'originalName': imageName,
        'contentType': contentType,
      },
    );
    await _images.doc(imageId).set(imageModel.toMap());
    if (kDebugMode) logger.i('[PlantService] ImageModel created for $imageId');

    if (existingPlantId == null) {
      PlantModel plantModel = PlantModel(
        plantId: plantId,
        userId: user.uid,
        createdAt: DateTime.now(),
        status: 'processing',
        images: [imageId],
      );
      await _plants.doc(plantId).set(plantModel.toMap());
      await _plants.doc(plantId).update({'lastAnalyzedImageId': imageId});
      await _users
          .doc(user.uid)
          .update({
            'plants': FieldValue.arrayUnion([plantId]),
          })
          .catchError((e) => logger.e("Error updating user's plant list: $e"));
      if (kDebugMode) {
        logger.i('[PlantService] New PlantModel created for $plantId');
      }
    } else {
      await _plants.doc(plantId).update({
        'images': FieldValue.arrayUnion([imageId]),
        'status': 'processing',
        'analysisError': FieldValue.delete(),
        'analysisResults': FieldValue.delete(),
      });
      if (kDebugMode) {
        logger.i('[PlantService] Existing PlantModel updated for $plantId');
      }
    }

    if (kDebugMode) {
      logger.i('[PlantService] Triggering analysis for $plantId...');
    }
    try {
      await _plants.doc(plantId).update({'status': 'analyzing'});

      Uint8List bytesToAnalyze = imageBytes;
      io.File? tempOriginalFileForSeg;
      io.File? segmentedFile;
      String? segmentationUrl;

      if (!kIsWeb) {
        // Only attempt segmentation on non-web platforms
        if (kDebugMode) {
          logger.i(
            '[PlantService NATIVE] Attempting segmentation for $plantId, original imageBytes length: ${imageBytes.length}',
          );
        }
        try {
          await _segmentationService
              .loadModel(); // Ensure model is loaded (idempotent)
          if (!_segmentationService.isModelLoaded) {
            if (kDebugMode) {
              logger.w(
                '[PlantService NATIVE] Segmentation model failed to load. Skipping segmentation.',
              );
            }
            // bytesToAnalyze remains original imageBytes
          } else {
            final tempDir = await io.Directory.systemTemp.createTemp(
              'plant_img_seg_',
            );
            tempOriginalFileForSeg = io.File(
              '${tempDir.path}/$imageId.$extension',
            );
            await tempOriginalFileForSeg.writeAsBytes(imageBytes);
            if (kDebugMode) {
              logger.i(
                '[PlantService NATIVE] Wrote temp file for segmentation: ${tempOriginalFileForSeg.path}',
              );
            }

            segmentedFile = await _segmentationService.segment(
              tempOriginalFileForSeg,
            );

            if (await segmentedFile.exists()) {
              final segmentedBytesLength = await segmentedFile.length();
              if (kDebugMode) {
                logger.i(
                  '[PlantService NATIVE] Segmentation successful. Segmented file: ${segmentedFile.path}, size: $segmentedBytesLength bytes',
                );
              }
              bytesToAnalyze = await segmentedFile.readAsBytes();
              if (kDebugMode) {
                logger.i(
                  '[PlantService NATIVE] Using segmented image bytes for analysis. Length: ${bytesToAnalyze.length}',
                );
              }

              try {
                segmentationUrl = await saveProcessedImage(
                  segmentedFile,
                  plantId,
                  imageId,
                  'segmentation',
                );
                if (kDebugMode) {
                  logger.i(
                    '[PlantService NATIVE] Uploaded segmentation image: $segmentationUrl',
                  );
                }
                await _images.doc(imageId).update({
                  'processedUrls.segmentation': segmentationUrl,
                });
              } catch (e) {
                if (kDebugMode) {
                  logger.w(
                    '[PlantService NATIVE] Failed to upload segmented image: $e',
                  );
                }
                // Continue with analysis even if upload of segmented image fails
              }
            } else {
              if (kDebugMode) {
                logger.w(
                  '[PlantService NATIVE] Segmentation returned null or file does not exist. Using original image bytes for analysis.',
                );
              }
              // bytesToAnalyze remains original imageBytes by default
            }
          }
        } catch (e, s) {
          if (kDebugMode) {
            logger.w(
              '[PlantService NATIVE] Segmentation process failed or was skipped: $e\n$s',
            );
          }
          // Fallback to original image bytes if segmentation fails
        } finally {
          try {
            if (tempOriginalFileForSeg != null &&
                await tempOriginalFileForSeg.exists()) {
              if (kDebugMode) {
                logger.i(
                  '[PlantService NATIVE] Deleting temp original file: ${tempOriginalFileForSeg.path}',
                );
              }
              await tempOriginalFileForSeg.delete();
              await tempOriginalFileForSeg.parent.delete();
            }
            // Note: segmentedFile might be in a cache or a path that SegmentationService itself manages.
            // If segmentedFile is also a temp file in a directory we created, it should be cleaned up too.
            // For now, assuming it's handled or its path is managed by SegmentationService if it's not the one we created.
          } catch (e) {
            if (kDebugMode) {
              logger.e(
                '[PlantService NATIVE] Error cleaning up temp file(s) for segmentation: $e',
              );
            }
          }
        }
      } else {
        if (kDebugMode) {
          logger.i(
            '[PlantService WEB] Skipping segmentation for web platform.',
          );
        }
      }
      // --- End Segmentation Step ---

      if (kDebugMode) {
        logger.i(
          '[PlantService] Bytes to analyze length for InferenceService: ${bytesToAnalyze.length}',
        );
      }

      // Specialized disease path based on local species classifier (extensible)
      if (!kIsWeb) {
        try {
          final speciesResult = await _classifySpecies(bytesToAnalyze);
          if (speciesResult != null) {
            final DetectionResult? specDet = await _detectSpecializedDisease(
              bytesToAnalyze,
              speciesResult.species,
            );
            if (specDet != null) {
              if (kDebugMode) {
                logger.i(
                  '[PlantService] Using specialized ${speciesResult.species.toUpperCase()} model: ${specDet.diseaseName} (${specDet.confidence.toStringAsFixed(2)})',
                );
              }
              final Map<String, dynamic> analysisData = {
                'detectedDisease': specDet.diseaseName,
                'confidence': specDet.confidence,
                'detectionTimestamp': DateTime.now().toIso8601String(),
                if (segmentationUrl != null) 'segmentationUrl': segmentationUrl,
                'plantSpecies': speciesResult.species,
                'plantSpeciesConfidence': speciesResult.confidence,
              };
              await _plants.doc(plantId).update({
                'status': 'completed',
                'analysisResults': analysisData,
                'analysisError': FieldValue.delete(),
              });
              return {
                'plantId': plantId,
                'imageId': imageId,
                'downloadUrl': downloadUrl,
              };
            }
          }
        } catch (e, s) {
          if (kDebugMode) {
            logger.w('[PlantService] Specialized detection skipped: $e\n$s');
          }
        }
      }
      DetectionResult? analysisResult = await _inferenceService.analyzeImage(
        imageBytes: bytesToAnalyze,
        plantId: plantId,
        isSegmented:
            segmentedFile != null &&
            await segmentedFile.exists(), // Pass segmentation status
      );

      if (analysisResult != null) {
        if (kDebugMode) {
          logger.i(
            '[PlantService] Inference complete for $plantId. Result: ${analysisResult.diseaseName}',
          );
        }
        Map<String, dynamic> analysisData = {
          'detectedDisease': analysisResult.diseaseName,
          'confidence': analysisResult.confidence,
          'detectionTimestamp': DateTime.now().toIso8601String(),
          // If your DetectionResult has more fields like a list of all results, map them here.
          // 'fullDetectionResults': (analysisResult.fullResults ?? []).map((r) => r.toMap()).toList(),
        };
        if (analysisResult.boundingBox != null) {
          analysisData['boundingBox'] = analysisResult.boundingBox!.toJson();
        }
        if (segmentationUrl != null) {
          // Add segmentation URL to results if it was generated and uploaded
          analysisData['segmentationUrl'] = segmentationUrl;
        }

        await _plants.doc(plantId).update({
          'status': 'completed',
          'analysisResults': analysisData,
          'analysisError':
              FieldValue.delete(), // Clear any previous error on success
        });
        if (kDebugMode) {
          logger.i(
            '[PlantService] Plant $plantId status updated to COMPLETED with results.',
          );
        }
      } else {
        if (kDebugMode) {
          logger.w(
            '[PlantService] Inference returned null (no result/error) for $plantId.',
          );
        }
        await _plants.doc(plantId).update({
          'status': 'error',
          'analysisError': 'Analysis did not return a valid result.',
        });
        if (kDebugMode) {
          logger.w('[PlantService] Plant $plantId status updated to ERROR.');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        logger.e(
          '[PlantService] Error during analysis call or Firestore update for $plantId: $e\n$stackTrace',
        );
      }
      await _plants
          .doc(plantId)
          .update({
            'status': 'error',
            'analysisError': 'Failed to complete analysis: ${e.toString()}',
          })
          .catchError((updateError) {
            if (kDebugMode) {
              logger.e(
                '[PlantService] CRITICAL: Failed to update plant $plantId to error state: $updateError',
              );
            }
          });
    }
    return {'plantId': plantId, 'imageId': imageId, 'downloadUrl': downloadUrl};
  }

  // This method is from the 'main' branch logic, retained for uploading processed images like segmentation results.
  Future<String> saveProcessedImage(
    io.File processedImage,
    String plantId,
    String originalImageId,
    String processType,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      const String extension =
          'jpg'; // Assuming processed images are saved as JPEG, adjust if necessary

      String storagePath = StorageUtils.getProcessedImagePath(
        user.uid,
        plantId,
        originalImageId,
        processType,
        extension,
      );
      Reference storageRef = _storage.ref().child(storagePath);
      await storageRef.putFile(
        processedImage,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'plantId': plantId,
            'imageId': originalImageId,
            'processType': processType,
            'processedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      String downloadUrl = await storageRef.getDownloadURL();
      // The main branch also updated _images.doc(originalImageId).update({'processedUrls.$processType': downloadUrl});
      // This is now handled in the main analysis flow if segmentationUrl is produced and we update ImageModel there.
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        logger.e(
          '[PlantService] Error saving processed image ($processType) for $originalImageId: $e',
        );
      }
      throw Exception('Failed to save processed image: $e');
    }
  }

  Future<List<PlantModel>> getUserPlants({int limit = 10}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    try {
      QuerySnapshot querySnapshot =
          await _plants
              .where('userId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();
      return querySnapshot.docs
          .map((doc) => PlantModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e.toString().contains('failed-precondition') ||
          e.toString().contains('requires an index')) {
        if (kDebugMode) {
          logger.w(
            '[PlantService] Index not available for getUserPlants, using fallback query without orderBy.',
          );
        }
        QuerySnapshot querySnapshot =
            await _plants
                .where('userId', isEqualTo: user.uid)
                .limit(limit)
                .get();
        var plants =
            querySnapshot.docs
                .map(
                  (doc) =>
                      PlantModel.fromMap(doc.data() as Map<String, dynamic>),
                )
                .toList();
        plants.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        ); // Manual sort for fallback
        return plants;
      } else {
        if (kDebugMode) {
          logger.e('[PlantService] Error getting user plants: $e');
        }
        rethrow;
      }
    }
  }

  Future<List<ImageModel>> getPlantImages(String plantId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    try {
      QuerySnapshot querySnapshot =
          await _images
              .where('plantId', isEqualTo: plantId)
              .orderBy('uploadTime', descending: true)
              .get();
      return querySnapshot.docs
          .map((doc) => ImageModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        logger.e('[PlantService] Error getting plant images for $plantId: $e');
      }
      rethrow;
    }
  }

  Future<void> deletePlant(String plantId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    try {
      List<ImageModel> images = await getPlantImages(plantId);
      await _plants.doc(plantId).delete(); // Delete plant doc first
      await _users.doc(user.uid).update({
        'plants': FieldValue.arrayRemove([plantId]),
      });

      for (var image in images) {
        try {
          await _images.doc(image.imageId).delete(); // Delete image doc

          String fileExtension =
              image.metadata?['contentType']?.split('/').last ??
              StorageUtils.getFileExtension(
                image.originalUrl,
              ); // Guess extension
          if (fileExtension == 'jpeg') fileExtension = 'jpg'; // Normalize
          if (fileExtension.isEmpty) {
            fileExtension = 'jpg'; // Default if still empty
          }

          // Delete original image from storage
          try {
            String originalPath = StorageUtils.getOriginalImagePath(
              user.uid,
              plantId,
              image.imageId,
              fileExtension,
            );
            await _storage.ref().child(originalPath).delete().catchError((
              error,
            ) {
              if (kDebugMode) {
                logger.w(
                  '[PlantService] Storage deletion (original) for ${image.imageId} error: $error. Continuing.',
                );
              }
              return null;
            });
          } catch (e) {
            if (kDebugMode) {
              logger.w(
                '[PlantService] Storage deletion (original) for ${image.imageId} failed: $e. Continuing.',
              );
            }
          }

          // Delete processed images from storage
          for (var entry in image.processedUrls.entries) {
            try {
              // String processType = entry.key; // Unused variable
              // String processedFileExtension = 'jpg'; // Assuming processed are jpg
              // String processedPath = StorageUtils.getProcessedImagePath(user.uid, plantId, image.imageId, processType, processedFileExtension);
              // Deleting by URL is not directly possible, need to reconstruct path or store paths.
              // For now, we'll skip deleting processed images from storage if only URL is known.
              // If entry.value is a full gs:// path, Firebase SDK might handle it.
              // Let's assume for now these are URLs and we can't reliably delete them without storage paths.
              if (kDebugMode) {
                logger.i(
                  '[PlantService] Skipping deletion of processed image (URL: ${entry.value}) for ${image.imageId} due to missing direct storage path info.',
                );
              }
            } catch (e) {
              if (kDebugMode) {
                logger.w(
                  '[PlantService] Error attempting to delete processed image for ${image.imageId} from storage: $e',
                );
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            logger.w(
              '[PlantService] Error deleting data for image ${image.imageId}: $e. Continuing.',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        logger.e('[PlantService] Error deleting plant $plantId: $e');
      }
      rethrow;
    }
  }

  Future<void> updatePlantAnalysis(
    String plantId,
    Map<String, dynamic> results,
  ) async {
    try {
      await _plants.doc(plantId).update({
        'status': 'completed',
        'analysisResults': results,
      });
    } catch (e) {
      if (kDebugMode) {
        logger.e(
          '[PlantService] Error updating plant analysis for $plantId: $e',
        );
      }
      rethrow;
    }
  }

  Stream<List<PlantModel>> userPlantsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(Exception('User not authenticated'));
    }
    final controller = StreamController<List<PlantModel>>.broadcast();
    void fetchData(bool withOrderBy) {
      Query query = _plants.where('userId', isEqualTo: user.uid);
      if (withOrderBy) {
        query = query.orderBy('createdAt', descending: true);
      }
      query.snapshots().listen(
        (snapshot) {
          final list =
              snapshot.docs
                  .map(
                    (doc) =>
                        PlantModel.fromMap(doc.data() as Map<String, dynamic>),
                  )
                  .toList();
          if (!withOrderBy && snapshot.docs.isNotEmpty) {
            // Sort in memory if not ordered by Firestore
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
          if (!controller.isClosed) controller.add(list);
        },
        onError: (error) {
          if (withOrderBy &&
              (error.toString().contains('failed-precondition') ||
                  error.toString().contains('requires an index'))) {
            if (kDebugMode) {
              logger.w(
                '[PlantService] userPlantsStream: Index error, falling back without orderBy: $error',
              );
            }
            fetchData(false); // Attempt fallback
          } else {
            if (kDebugMode) {
              logger.e(
                '[PlantService] userPlantsStream: Stream error (orderBy: $withOrderBy): $error',
              );
            }
            if (!controller.isClosed) controller.addError(error);
          }
        },
      );
    }

    fetchData(true); // Initial attempt with orderBy
    return controller.stream;
  }
}

class _SpeciesResult {
  final String species;
  final double confidence;
  const _SpeciesResult(this.species, this.confidence);
}

extension on PlantService {
  static const Map<String, String> _speciesModelPath = {
    'corn': 'assets/models/corn_disease_detector.tflite',
    'pepper': 'assets/models/pepper_disease_detector.tflite',
    'grape': 'assets/models/grape_disease_detector.tflite',
  };

  static const Map<String, List<String>> _speciesLabels = {
    'corn': [
      'Corn___Cercospora_leaf_spot_Gray_leaf_spot',
      'Corn___Common_rust',
      'Corn___healthy',
      'Corn___Northern_Leaf_Blight',
    ],
    'pepper': ['Pepper_bacterial_spot', 'Pepper_healthy'],
    'grape': [
      'Grape___Black_rot',
      'Grape___Esca_(Black_Measles)',
      'Grape___healthy',
      'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
    ],
  };
  Future<_SpeciesResult?> _classifySpecies(Uint8List bytes) async {
    try {
      final img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final img.Image resized = img.copyResize(
        decoded,
        width: 224,
        height: 224,
      );
      final input = [
        List.generate(
          224,
          (y) => List.generate(224, (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          }),
        ),
      ];
      final interpreter = TfliteInterpreter();
      await interpreter.loadModel('assets/models/plants_detector.tflite');
      final output = [List.filled(14, 0.0)];
      interpreter.run(input, output);
      interpreter.close();
      final probs = (output[0] as List).cast<double>();
      int maxIdx = 0;
      double maxVal = -1;
      for (int i = 0; i < probs.length; i++) {
        if (probs[i] > maxVal) {
          maxVal = probs[i];
          maxIdx = i;
        }
      }
      const labels = [
        'apple',
        'blueberry',
        'cherry',
        'corn',
        'grape',
        'orange',
        'peach',
        'pepper',
        'potato',
        'raspberry',
        'soybean',
        'squash',
        'strawberry',
        'tomato',
      ];
      final species = labels[maxIdx].toLowerCase().trim();
      return _SpeciesResult(species, maxVal);
    } catch (_) {
      return null;
    }
  }

  Future<DetectionResult?> _detectSpecializedDisease(
    Uint8List bytes,
    String species,
  ) async {
    final key = species.toLowerCase().trim();
    if (!_speciesModelPath.containsKey(key)) return null;
    try {
      final img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final img.Image resized = img.copyResize(
        decoded,
        width: 224,
        height: 224,
      );
      final input = [
        List.generate(
          224,
          (y) => List.generate(224, (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          }),
        ),
      ];
      final interpreter = TfliteInterpreter();
      await interpreter.loadModel(_speciesModelPath[key]!);
      final labels = _speciesLabels[key]!;
      final output = [List.filled(labels.length, 0.0)];
      interpreter.run(input, output);
      interpreter.close();
      final probs = (output[0] as List).cast<double>();
      int maxIdx = 0;
      double maxVal = -1;
      for (int i = 0; i < probs.length; i++) {
        if (probs[i] > maxVal) {
          maxVal = probs[i];
          maxIdx = i;
        }
      }
      final diseaseName =
          (maxIdx >= 0 && maxIdx < labels.length)
              ? labels[maxIdx]
              : '${species[0].toUpperCase()}${species.substring(1)}___Unknown';
      return DetectionResult(
        diseaseName: diseaseName,
        confidence: maxVal,
        boundingBox: null,
      );
    } catch (_) {
      return null;
    }
  }
}
