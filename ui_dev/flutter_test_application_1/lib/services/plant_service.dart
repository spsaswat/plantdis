import 'dart:io' as io;
// Added for Uint8List
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/plant_model.dart';
import '../models/image_model.dart';
import '../models/detection_result.dart'; // Import DetectionResult model
import '../utils/storage_utils.dart';
import './inference_service.dart'; // Added for InferenceService
import 'dart:async';

class PlantService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InferenceService _inferenceService = InferenceService(); // Added

  // Collection references
  CollectionReference get _plants => _firestore.collection('plants');
  CollectionReference get _images => _firestore.collection('images');
  CollectionReference get _users => _firestore.collection('users');

  /// Uploads an image, creates associated records, triggers analysis via InferenceService,
  /// and updates Firestore with the results.
  Future<Map<String, dynamic>> uploadAndAnalyzeImage({
    required XFile image, // Still taking XFile for convenience from UI
    String? notes,
    String? existingPlantId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final String plantId = existingPlantId ?? StorageUtils.generatePlantId();
    final String imageId = StorageUtils.generateImageId();

    // Read bytes from XFile
    final Uint8List imageBytes = await image.readAsBytes();
    final String imageName =
        image.name; // For content type or metadata if needed

    // Determine extension for content type
    String extension;
    if (kIsWeb) {
      final mimeType = image.mimeType; // XFile provides mimeType
      if (mimeType == 'image/png') {
        extension = 'png';
      } else if (mimeType == 'image/jpeg') {
        extension = 'jpg';
      } else {
        // Fallback or throw error for unsupported web types
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

    // Prepare storage path
    String storagePath = StorageUtils.getOriginalImagePath(
      user.uid,
      plantId,
      imageId,
      extension,
    );
    Reference storageRef = _storage.ref().child(storagePath);

    // Upload image bytes
    if (kDebugMode)
      print('[PlantService] Uploading image bytes to $storagePath...');
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
    if (kDebugMode) print('[PlantService] Image uploaded to $downloadUrl');

    // Create ImageModel Firestore document
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
    if (kDebugMode) print('[PlantService] ImageModel created for $imageId');

    // Create or update PlantModel, set status to 'processing' initially
    if (existingPlantId == null) {
      PlantModel plantModel = PlantModel(
        plantId: plantId,
        userId: user.uid,
        createdAt: DateTime.now(),
        status: 'processing', // Initial status
        images: [imageId],
      );
      await _plants.doc(plantId).set(plantModel.toMap());
      await _plants.doc(plantId).update({'lastAnalyzedImageId': imageId});
      await _users
          .doc(user.uid)
          .update({
            'plants': FieldValue.arrayUnion([plantId]),
          })
          .catchError(
            (e) => print("Error updating user's plant list: $e"),
          ); // Optional: catch error
      if (kDebugMode)
        print('[PlantService] New PlantModel created for $plantId');
    } else {
      await _plants.doc(plantId).update({
        'images': FieldValue.arrayUnion([imageId]),
        'status': 'processing', // Re-set status for new analysis
        'analysisError': FieldValue.delete(), // Clear previous error
        'analysisResults': FieldValue.delete(), // Clear previous results
      });
      if (kDebugMode)
        print('[PlantService] Existing PlantModel updated for $plantId');
    }

    // Trigger analysis via InferenceService and update PlantModel with results
    if (kDebugMode)
      print(
        '[PlantService] Triggering analysis for $plantId via InferenceService...',
      );
    try {
      await _plants.doc(plantId).update({
        'status': 'analyzing',
      }); // Update status before async call

      DetectionResult? analysisResult = await _inferenceService.analyzeImage(
        imageBytes: imageBytes,
        plantId: plantId,
      );

      if (analysisResult != null) {
        if (kDebugMode)
          print(
            '[PlantService] Inference complete for $plantId. Result: ${analysisResult.diseaseName}',
          );
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

        await _plants.doc(plantId).update({
          'status': 'completed',
          'analysisResults': analysisData,
          'analysisError': null, // Clear any previous error on success
        });
        if (kDebugMode)
          print(
            '[PlantService] Plant $plantId status updated to COMPLETED with results.',
          );
      } else {
        if (kDebugMode)
          print(
            '[PlantService] Inference returned null (no result/error) for $plantId.',
          );
        await _plants.doc(plantId).update({
          'status': 'error',
          'analysisError': 'Analysis did not return a valid result.',
        });
        if (kDebugMode)
          print('[PlantService] Plant $plantId status updated to ERROR.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print(
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
            if (kDebugMode)
              print(
                '[PlantService] CRITICAL: Failed to update plant $plantId to error state: $updateError',
              );
          });
    }

    return {'plantId': plantId, 'imageId': imageId, 'downloadUrl': downloadUrl};
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

      // Delete the Firestore documents first to ensure the operation completes even if storage fails
      // Delete plant document first to prevent new operations on it
      await _plants.doc(plantId).delete();

      // Remove from user's plants list
      await _users.doc(user.uid).update({
        'plants': FieldValue.arrayRemove([plantId]),
      });

      // Now delete the images (after the main documents are gone)
      bool isLastImage = images.length <= 1;

      for (var image in images) {
        try {
          // Delete image document first
          await _images.doc(image.imageId).delete();

          // Then try to delete the storage files with a timeout
          // Delete original image with timeout
          try {
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
                .delete()
                .timeout(
                  // Shorter timeout for normal images, longer for last image
                  Duration(seconds: isLastImage ? 8 : 3),
                  onTimeout: () {
                    print(
                      'Storage deletion timed out, continuing with operation',
                    );
                    return;
                  },
                )
                .catchError((error) {
                  if (error.toString().contains('object-not-found') ||
                      error.toString().contains('Not Found')) {
                    print(
                      'Warning: Image file not found in storage, but continuing with deletion',
                    );
                    // Continue with deletion process
                    return null;
                  } else {
                    // Log other errors but don't fail the whole operation
                    print('Error deleting from storage: $error');
                    return null;
                  }
                });
          } catch (e) {
            // Log but continue
            print('Error deleting original image from storage: $e');
          }

          // Delete processed images with timeout
          for (var processedUrl in image.processedUrls.entries) {
            try {
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
                  .delete()
                  .timeout(
                    // Shorter timeout for processed images
                    const Duration(seconds: 2),
                    onTimeout: () {
                      print(
                        'Processed image deletion timed out, continuing with operation',
                      );
                      return;
                    },
                  )
                  .catchError((error) {
                    if (error.toString().contains('object-not-found') ||
                        error.toString().contains('Not Found')) {
                      print(
                        'Warning: Processed image file not found in storage, but continuing with deletion',
                      );
                      // Continue with deletion process
                      return null;
                    } else {
                      // Log other errors but don't fail the whole operation
                      print(
                        'Error deleting processed image from storage: $error',
                      );
                      return null;
                    }
                  });
            } catch (e) {
              // Log but continue
              print('Error deleting processed image from storage: $e');
            }
          }
        } catch (e) {
          print('Error deleting image: $e');
          // Continue with other images instead of failing completely
        }
      }

      // Operation is considered successful even if some storage deletions failed
      // since the database entries are gone
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
    if (user == null) {
      // Return a stream that emits an error if the user is not authenticated.
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
            if (kDebugMode)
              print(
                'userPlantsStream: Index error, falling back without orderBy: $error',
              );
            fetchData(false); // Attempt fallback without orderBy
          } else {
            if (kDebugMode)
              print(
                'userPlantsStream: Stream error (orderBy: $withOrderBy): $error',
              );
            if (!controller.isClosed) controller.addError(error);
            // Optionally close the controller on error, or let it continue trying if that makes sense.
            // controller.close();
          }
        },
        onDone: () {
          // if (kDebugMode) print('userPlantsStream: Stream (orderBy: $withOrderBy) done.');
          // Don't close the controller here as snapshots() streams are continuous unless an error occurs
          // that isn't handled by a retry (like the index fallback).
        },
      );
    }

    fetchData(true); // Initial attempt with orderBy

    return controller.stream;
  }
}
