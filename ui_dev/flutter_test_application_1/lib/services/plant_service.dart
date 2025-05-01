import 'dart:io' as io;
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/plant_model.dart';
import '../models/image_model.dart';
import '../models/detection_result.dart'; // Import DetectionResult model
import '../utils/storage_utils.dart';
import './detection_service.dart'; // Import DetectionService
import 'package:flutter/material.dart';
import 'dart:async';

class PlantService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DetectionService _detectionService = DetectionService();

  // Collection references
  CollectionReference get _plants => _firestore.collection('plants');
  CollectionReference get _images => _firestore.collection('images');
  CollectionReference get _users => _firestore.collection('users');

  /// Upload a new plant image and create associated records
  Future<Map<String, dynamic>> uploadPlantImage(
    XFile image, {
    String? notes,
    String? existingPlantId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final String plantId = existingPlantId ?? StorageUtils.generatePlantId();
      final String imageId = StorageUtils.generateImageId();

      // Determine extension
      String extension;
      if (kIsWeb) {
        final mimeType = await image.mimeType;
        if (mimeType == 'image/png') {
          extension = 'png';
        } else if (mimeType == 'image/jpeg') {
          extension = 'jpg';
        } else {
          throw Exception(
            'Invalid image format. Supported formats: jpg, jpeg, png',
          );
        }
      } else {
        extension = StorageUtils.getFileExtension(image.path);
        if (!StorageUtils.isValidImageExtension(extension)) {
          throw Exception(
            'Invalid image format. Supported formats: jpg, jpeg, png',
          );
        }
      }

      // Prepare storage path
      String storagePath = StorageUtils.getOriginalImagePath(
        user.uid,
        plantId,
        imageId,
        extension,
      );

      Reference storageRef = _storage.ref().child(storagePath);
      UploadTask uploadTask;
      io.File? localFile; // To hold the file for analysis

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(
            contentType: StorageUtils.getContentType(extension),
            customMetadata: {
              'plantId': plantId,
              'imageId': imageId,
              'userId': user.uid,
              'uploadTime': DateTime.now().toIso8601String(),
            },
          ),
        );
        // For web, we don't have a direct io.File, analysis might need adjustment
        // or we assume analysis is triggered differently for web.
        // For now, localFile remains null for web uploads.
      } else {
        localFile = io.File(image.path);
        uploadTask = storageRef.putFile(
          localFile,
          SettableMetadata(
            contentType: StorageUtils.getContentType(extension),
            customMetadata: {
              'plantId': plantId,
              'imageId': imageId,
              'userId': user.uid,
              'uploadTime': DateTime.now().toIso8601String(),
            },
          ),
        );
      }

      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Create Firestore document
      ImageModel imageModel = ImageModel(
        imageId: imageId,
        plantId: plantId,
        userId: user.uid,
        originalUrl: downloadUrl,
        processedUrls: {},
        uploadTime: DateTime.now(),
        metadata: {'notes': notes},
      );

      await _images.doc(imageId).set(imageModel.toMap());

      // Create or update PlantModel before triggering analysis
      if (existingPlantId == null) {
        PlantModel plantModel = PlantModel(
          plantId: plantId,
          userId: user.uid,
          createdAt: DateTime.now(),
          status: 'processing', // Set initial status to processing
          images: [imageId],
          // analysisResults: null, // Explicitly null initially
        );
        await _plants.doc(plantId).set(plantModel.toMap());
        await _users.doc(user.uid).update({
          'plants': FieldValue.arrayUnion([plantId]),
        });
      } else {
        // If adding to existing plant, ensure its status indicates processing might occur
        // This logic might need refinement depending on how re-analysis is handled.
        await _plants.doc(plantId).update({
          'images': FieldValue.arrayUnion([imageId]),
          'status':
              'processing', // Update status if a new image triggers processing
        });
      }

      // Trigger analysis only if we have a local file (i.e., not web for now)
      if (localFile != null) {
        // Use unawaited here if we don't need to wait for analysis completion in this function
        _runAnalysis(plantId, imageId, localFile);
      } else if (kIsWeb) {
        // Handle web: Maybe trigger a cloud function or mark as needs manual analysis?
        print("Web upload completed, analysis needs separate trigger.");
        await _plants.doc(plantId).update({
          'status': 'pending_web_analysis', // Indicate special status for web
        });
      }

      return {
        'plantId': plantId,
        'imageId': imageId,
        'downloadUrl': downloadUrl,
      };
    } catch (e) {
      print('Error uploading plant image: $e');
      throw Exception('Failed to upload plant image: $e');
    }
  }

  /// Runs the ML model analysis on the uploaded image file.
  Future<void> _runAnalysis(
    String plantId,
    String imageId,
    io.File imageFile,
  ) async {
    List<DetectionResult>? detectionResults;
    dynamic analysisError;

    if (kDebugMode)
      print('[_runAnalysis] Starting for plant: $plantId, image: $imageId');
    try {
      // 1. Ensure model is loaded
      await _detectionService.loadModel();
      if (!_detectionService.isModelLoaded) {
        throw Exception('Model failed to load before analysis.');
      }

      // 2. Update status to analyzing (before starting detection)
      await _plants.doc(plantId).update({'status': 'analyzing'});

      // 3. Perform detection (Await the result)
      detectionResults = await _detectionService.detect(imageFile, plantId);

      // If detect completes without error, proceed to update Firestore with results
      if (kDebugMode)
        print('[_runAnalysis] Detection completed for plant: $plantId');
    } catch (e, stackTrace) {
      if (kDebugMode)
        print(
          '[_runAnalysis] Error during analysis execution for plant $plantId: $e\n$stackTrace',
        );
      analysisError = e; // Store the error
      // NOTE: Firestore status update happens in the finally block
    }

    // 4. Update Firestore based on success or failure
    try {
      if (analysisError != null) {
        // Update status to error
        await _plants.doc(plantId).update({
          'status': 'error',
          'analysisError': analysisError.toString(),
        });
        if (kDebugMode)
          print('[_runAnalysis] Updated plant $plantId status to error.');
      } else if (detectionResults != null) {
        // Format and save successful results
        Map<String, dynamic> analysisData = {};
        if (detectionResults.isNotEmpty) {
          final topResult = detectionResults.first;
          if (kDebugMode) {
            print(
              '[_runAnalysis] Top detection result: ${topResult.diseaseName} with confidence ${topResult.confidence}',
            );
          }
          analysisData = {
            'detectedDisease': topResult.diseaseName,
            'confidence': topResult.confidence,
            'detectionTimestamp': DateTime.now().toIso8601String(),
            'fullDetectionResults':
                detectionResults.map((r) => r.toMap()).toList(), // Use .toMap()
          };
        } else {
          if (kDebugMode) {
            print(
              '[_runAnalysis] Detection results array is empty! Using fallback result.',
            );
          }
          analysisData = {
            'detectedDisease': 'No disease detected',
            'confidence': 0.0,
            'detectionTimestamp': DateTime.now().toIso8601String(),
          };
        }
        if (kDebugMode) {
          print(
            '[_runAnalysis] Updating Firestore document for plant $plantId with analysis data: $analysisData',
          );
        }
        await _plants.doc(plantId).update({
          'status': 'completed',
          'analysisResults': analysisData,
          'lastAnalyzedImageId': imageId,
          'lastAnalyzedTimestamp': FieldValue.serverTimestamp(),
        });
        // Verify the update was successful by reading the document back
        if (kDebugMode) {
          try {
            final updatedDoc = await _plants.doc(plantId).get();
            final data = updatedDoc.data() as Map<String, dynamic>?;
            print(
              '[_runAnalysis] Verification - updated document: status=${data?['status']}, analysisResults=${data?['analysisResults']}',
            );
          } catch (e) {
            print('[_runAnalysis] Error verifying document update: $e');
          }
        }
        if (kDebugMode)
          print('[_runAnalysis] Updated plant $plantId status to completed.');
      } else {
        // Should not happen if error handling is correct, but as a fallback:
        await _plants.doc(plantId).update({
          'status': 'error',
          'analysisError': 'Unknown state after analysis.',
        });
        if (kDebugMode)
          print('[_runAnalysis] Plant $plantId ended in unknown state.');
      }
    } catch (updateError) {
      if (kDebugMode)
        print(
          '[_runAnalysis] CRITICAL: Failed to update plant $plantId final status: $updateError',
        );
      // Consider additional error handling/logging here
    }
  }

  /// Save a processed image
  Future<String> saveProcessedImage(
    io.File processedImage,
    String plantId,
    String originalImageId,
    String processType,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final String extension = 'jpg'; // Processed images are always JPEG

      // Get storage path for processed image
      String storagePath = StorageUtils.getProcessedImagePath(
        user.uid,
        plantId,
        originalImageId,
        processType,
        extension,
      );

      // Upload processed image
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

      // Get download URL
      String downloadUrl = await storageRef.getDownloadURL();

      // Update image document with processed URL
      await _images.doc(originalImageId).update({
        'processedUrls.$processType': downloadUrl,
      });

      return downloadUrl;
    } catch (e) {
      print('Error saving processed image: $e');
      throw Exception('Failed to save processed image: $e');
    }
  }

  /// Get all plants for the current user
  Future<List<PlantModel>> getUserPlants({int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      try {
        // Try the optimized query first (requires index)
        QuerySnapshot querySnapshot =
            await _plants
                .where('userId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .limit(limit)
                .get();

        return querySnapshot.docs
            .map(
              (doc) => PlantModel.fromMap(doc.data() as Map<String, dynamic>),
            )
            .toList();
      } catch (e) {
        if (e.toString().contains('failed-precondition') ||
            e.toString().contains('requires an index')) {
          // Fallback to simple query if index is not available
          print('Index not available, using fallback query');
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

          // Sort in memory instead
          plants.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return plants;
        } else {
          rethrow;
        }
      }
    } catch (e) {
      print('Error getting user plants: $e');
      throw Exception('Failed to get user plants: $e');
    }
  }

  /// Get images for a specific plant
  Future<List<ImageModel>> getPlantImages(String plantId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      QuerySnapshot querySnapshot =
          await _images
              .where('plantId', isEqualTo: plantId)
              .orderBy('uploadTime', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => ImageModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting plant images: $e');
      throw Exception('Failed to get plant images: $e');
    }
  }

  /// Delete a plant and all its images
  Future<void> deletePlant(String plantId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get all images for this plant
      List<ImageModel> images = await getPlantImages(plantId);

      // Delete all images from Storage
      for (var image in images) {
        // Delete original image
        await _storage
            .ref()
            .child(
              StorageUtils.getOriginalImagePath(
                user.uid,
                plantId,
                image.imageId,
                'jpg',
              ),
            )
            .delete();

        // Delete processed images
        for (var processedUrl in image.processedUrls.entries) {
          await _storage
              .ref()
              .child(
                StorageUtils.getProcessedImagePath(
                  user.uid,
                  plantId,
                  image.imageId,
                  processedUrl.key,
                  'jpg',
                ),
              )
              .delete();
        }

        // Delete image document
        await _images.doc(image.imageId).delete();
      }

      // Delete plant document
      await _plants.doc(plantId).delete();

      // Remove from user's plants list
      await _users.doc(user.uid).update({
        'plants': FieldValue.arrayRemove([plantId]),
      });
    } catch (e) {
      print('Error deleting plant: $e');
      throw Exception('Failed to delete plant: $e');
    }
  }

  /// Update plant analysis results
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
      print('Error updating plant analysis: $e');
      throw Exception('Failed to update plant analysis: $e');
    }
  }

  /// Real-time stream of PlantModel list with error fallback for missing composite index.
  Stream<List<PlantModel>> userPlantsStream() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    // Controller to emit plant lists
    final controller = StreamController<List<PlantModel>>();
    // Attempt with orderBy (requires index)
    _plants
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            // Map documents to models
            final list =
                snapshot.docs
                    .map(
                      (doc) => PlantModel.fromMap(
                        doc.data() as Map<String, dynamic>,
                      ),
                    )
                    .toList();
            controller.add(list);
          },
          onError: (error) {
            // Fallback: missing index -> listen without orderBy and sort in memory
            print(
              'userPlantsStream: index error, falling back without orderBy: $error',
            );
            _plants
                .where('userId', isEqualTo: user.uid)
                .snapshots()
                .listen(
                  (snap) {
                    final list =
                        snap.docs
                            .map(
                              (doc) => PlantModel.fromMap(
                                doc.data() as Map<String, dynamic>,
                              ),
                            )
                            .toList();
                    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    controller.add(list);
                  },
                  onError: (e) {
                    // If fallback also fails, log but do not propagate error
                    print('userPlantsStream fallback error: $e');
                  },
                );
          },
        );
    return controller.stream;
  }
}
