import 'dart:io' as io;
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/plant_model.dart';
import '../models/image_model.dart';
import '../utils/storage_utils.dart';

class PlantService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
          throw Exception('Invalid image format. Supported formats: jpg, jpeg, png');
        }
      } else {
        extension = StorageUtils.getFileExtension(image.path);
        if (!StorageUtils.isValidImageExtension(extension)) {
          throw Exception('Invalid image format. Supported formats: jpg, jpeg, png');
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
      } else {
        final io.File imageFile = io.File(image.path);
        uploadTask = storageRef.putFile(
          imageFile,
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

      if (existingPlantId == null) {
        PlantModel plantModel = PlantModel(
          plantId: plantId,
          userId: user.uid,
          createdAt: DateTime.now(),
          status: 'pending',
          images: [imageId],
        );

        await _plants.doc(plantId).set(plantModel.toMap());

        await _users.doc(user.uid).update({
          'plants': FieldValue.arrayUnion([plantId]),
        });
      } else {
        await _plants.doc(plantId).update({
          'images': FieldValue.arrayUnion([imageId]),
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
}
