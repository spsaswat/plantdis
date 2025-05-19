import 'dart:async';
import 'dart:typed_data'; // For Uint8List
import 'dart:io' as io;    // For File operations on mobile, conditionally used

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb, kDebugMode

import '../models/plant_model.dart';
import '../models/image_model.dart';
import '../models/detection_result.dart';
import '../utils/storage_utils.dart';
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
          .catchError(
            (e) => print("Error updating user's plant list: $e"),
          );
      if (kDebugMode)
        print('[PlantService] New PlantModel created for $plantId');
    } else {
      await _plants.doc(plantId).update({
        'images': FieldValue.arrayUnion([imageId]),
        'status': 'processing',
        'analysisError': FieldValue.delete(),
        'analysisResults': FieldValue.delete(),
      });
      if (kDebugMode)
        print('[PlantService] Existing PlantModel updated for $plantId');
    }

    if (kDebugMode)
      print(
        '[PlantService] Triggering analysis for $plantId...',
      );
    try {
      await _plants.doc(plantId).update({
        'status': 'analyzing',
      });

      Uint8List bytesToAnalyze = imageBytes;
      io.File? tempOriginalFileForSeg;
      io.File? segmentedFile;
      String? segmentationUrl;

      if (!kIsWeb) { // Only attempt segmentation on non-web platforms
        if (kDebugMode) print('[PlantService] Attempting segmentation for $plantId on native platform...');
        try {
          await _segmentationService.loadModel();
          
          // Create a temporary file from imageBytes to pass to segmentation service
          final tempDir = await io.Directory.systemTemp.createTemp('plant_img_seg_');
          // Try to retain original extension for the temp file if possible, helps some libraries
          tempOriginalFileForSeg = io.File('${tempDir.path}/$imageId.$extension');
          await tempOriginalFileForSeg.writeAsBytes(imageBytes);
          if (kDebugMode) print('[PlantService] Wrote temp file for segmentation: ${tempOriginalFileForSeg.path}');

          segmentedFile = await _segmentationService.segment(tempOriginalFileForSeg); // Assumes segment() takes io.File

          if (segmentedFile != null && await segmentedFile.exists()) {
            if (kDebugMode) print('[PlantService] Segmentation successful: ${segmentedFile.path}');
            bytesToAnalyze = await segmentedFile.readAsBytes(); // Use segmented image bytes for detection
            
            // Upload segmented image
            segmentationUrl = await saveProcessedImage(
              segmentedFile, 
              plantId, 
              imageId, // original imageId to associate with
              'segmentation' // processType
            );
            if (kDebugMode) print('[PlantService] Uploaded segmentation image: $segmentationUrl');
            // Update the ImageModel with the URL of the processed (segmented) image
            await _images.doc(imageId).update({'processedUrls.segmentation': segmentationUrl});

          } else {
            if (kDebugMode) print('[PlantService] Segmentation did not return a valid file, using original image.');
          }
        } catch (e,s) {
          if (kDebugMode) print('[PlantService] Segmentation failed or was skipped during execution: $e\n$s');
          // Fallback to original image bytes if segmentation fails
        } finally {
          // Clean up temporary files
          try {
            if (tempOriginalFileForSeg != null && await tempOriginalFileForSeg.exists()) {
              await tempOriginalFileForSeg.delete();
              // Only delete parent if we are sure it's empty and we created it uniquely for this file.
              // The createTemp gives a unique directory, so it should be safe.
              await tempOriginalFileForSeg.parent.delete(); 
            }
            // If segmentedFile is also temporary and not managed by SegmentationService, handle its deletion.
            // This example assumes segmentedFile might be in a cache or a path that doesn't need explicit deletion here
            // or that its lifecycle is managed by _segmentationService.
          } catch (e) {
            if (kDebugMode) print('[PlantService] Error cleaning up temp file(s) for segmentation: $e');
          }
        }
      }
      // --- End Segmentation Step ---

      DetectionResult? analysisResult = await _inferenceService.analyzeImage(
        imageBytes: bytesToAnalyze,
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
        if (segmentationUrl != null) { // Add segmentation URL to results if it was generated and uploaded
           analysisData['segmentationUrl'] = segmentationUrl;
        }

        await _plants.doc(plantId).update({
          'status': 'completed',
          'analysisResults': analysisData,
          'analysisError': FieldValue.delete(), // Clear any previous error on success
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

      final String extension = 'jpg'; // Assuming processed images are saved as JPEG, adjust if necessary

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
      if (kDebugMode) print('[PlantService] Error saving processed image ($processType) for $originalImageId: $e');
      throw Exception('Failed to save processed image: $e');
    }
  }

  Future<List<PlantModel>> getUserPlants({int limit = 10}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    try {
      QuerySnapshot querySnapshot = await _plants
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
        if (kDebugMode) print('[PlantService] Index not available for getUserPlants, using fallback query without orderBy.');
        QuerySnapshot querySnapshot = await _plants
            .where('userId', isEqualTo: user.uid)
            .limit(limit)
            .get();
        var plants = querySnapshot.docs
            .map((doc) => PlantModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
        plants.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Manual sort for fallback
        return plants;
      } else {
        if (kDebugMode) print('[PlantService] Error getting user plants: $e');
        rethrow;
      }
    }
  }

  Future<List<ImageModel>> getPlantImages(String plantId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    try {
      QuerySnapshot querySnapshot = await _images
          .where('plantId', isEqualTo: plantId)
          .orderBy('uploadTime', descending: true)
          .get();
      return querySnapshot.docs
          .map((doc) => ImageModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('[PlantService] Error getting plant images for $plantId: $e');
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
          
          String fileExtension = image.metadata?['contentType']?.split('/').last ?? 
                                 StorageUtils.getFileExtension(image.originalUrl); // Guess extension
          if (fileExtension == 'jpeg') fileExtension = 'jpg'; // Normalize
          if (fileExtension.isEmpty) fileExtension = 'jpg'; // Default if still empty

          // Delete original image from storage
          try {
            String originalPath = StorageUtils.getOriginalImagePath(user.uid, plantId, image.imageId, fileExtension);
            await _storage.ref().child(originalPath).delete().catchError((error) {
              if (kDebugMode) print('[PlantService] Storage deletion (original) for ${image.imageId} error: $error. Continuing.');
              return null;
            });
          } catch (e) {
            if (kDebugMode) print('[PlantService] Storage deletion (original) for ${image.imageId} failed: $e. Continuing.');
          }

          // Delete processed images from storage
          for (var entry in image.processedUrls.entries) {
            try {
              String processType = entry.key;
              // String processedFileExtension = 'jpg'; // Assuming processed are jpg
              // String processedPath = StorageUtils.getProcessedImagePath(user.uid, plantId, image.imageId, processType, processedFileExtension);
              // Deleting by URL is not directly possible, need to reconstruct path or store paths.
              // For now, we'll skip deleting processed images from storage if only URL is known.
              // If entry.value is a full gs:// path, Firebase SDK might handle it.
              // Let's assume for now these are URLs and we can't reliably delete them without storage paths.
              if (kDebugMode) print('[PlantService] Skipping deletion of processed image (URL: ${entry.value}) for ${image.imageId} due to missing direct storage path info.');
            } catch (e) {
              if (kDebugMode) print('[PlantService] Error attempting to delete processed image for ${image.imageId} from storage: $e');
            }
          }
        } catch (e) {
          if (kDebugMode) print('[PlantService] Error deleting data for image ${image.imageId}: $e. Continuing.');
        }
      }
    } catch (e) {
      if (kDebugMode) print('[PlantService] Error deleting plant $plantId: $e');
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
      if (kDebugMode) print('[PlantService] Error updating plant analysis for $plantId: $e');
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
          final list = snapshot.docs
              .map((doc) => PlantModel.fromMap(doc.data() as Map<String, dynamic>))
              .toList();
          if (!withOrderBy && snapshot.docs.isNotEmpty) { // Sort in memory if not ordered by Firestore
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
          if (!controller.isClosed) controller.add(list);
        },
        onError: (error) {
          if (withOrderBy &&
              (error.toString().contains('failed-precondition') ||
                  error.toString().contains('requires an index'))) {
            if (kDebugMode) print('[PlantService] userPlantsStream: Index error, falling back without orderBy: $error');
            fetchData(false); // Attempt fallback
          } else {
            if (kDebugMode) print('[PlantService] userPlantsStream: Stream error (orderBy: $withOrderBy): $error');
            if (!controller.isClosed) controller.addError(error);
          }
        },
      );
    }
    fetchData(true); // Initial attempt with orderBy
    return controller.stream;
  }
}
