import 'dart:io' as io; // Alias to avoid conflict in web
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_test_application_1/services/user_service.dart';

class DatabaseService {
  final User _user = FirebaseAuth.instance.currentUser!;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  // Reference to the users collection
  CollectionReference get _users => _firestore.collection('users');

  // Reference to the images collection
  CollectionReference get _images => _firestore.collection('images');

  // Reference to the plants collection
  CollectionReference get _plants => _firestore.collection('plants');

  // Upload image to Firebase Storage and save metadata to Firestore
  Future<Map<String, dynamic>> uploadImage(
    XFile image, {
    String? plantType,
    String? notes,
  }) async {
    try {
      // Create a unique filename
      String fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Define the storage path - organize by user ID and session if anonymous
      String userFolder =
          _user.isAnonymous
              ? "anonymous/${await _userService.getUserIpAddress()}"
              : _user.uid;
      String storagePath = "user_images/$userFolder/$fileName";

      // Create a reference to the storage location
      Reference storageRef = _storage.ref().child(storagePath);

      UploadTask uploadTask;

      if (kIsWeb) {
        // Web: Read image bytes and upload
        final bytes = await image.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: "image/jpeg"),
        );
      } else {
        // Mobile: Create a file from the XFile and upload
        io.File imageFile = io.File(image.path);
        uploadTask = storageRef.putFile(
          imageFile,
          SettableMetadata(contentType: "image/jpeg"),
        );
      }

      uploadTask.snapshotEvents.listen((TaskSnapshot taskSnapshot) {
        switch (taskSnapshot.state) {
          case TaskState.running:
            final progress =
                100.0 *
                (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes);
            print("Upload is $progress% complete.");
            CircularProgressIndicator.adaptive();
            break;
          case TaskState.paused:
            print("Upload is paused.");
            break;
          case TaskState.canceled:
            print("Upload was cancelled");
            break;
          case TaskState.error:
            print("Upload encountered an error");
            break;
          case TaskState.success:
            print("Upload Successful");
            break;
        }
      });

      // Wait for the upload to complete and get the download URL
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Prepare image metadata to store in Firestore
      Map<String, dynamic> imageData = {
        'userId': _user.uid,
        'isAnonymous': _user.isAnonymous,
        'fileName': fileName,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'uploadTime': FieldValue.serverTimestamp(),
        'plantType': plantType,
        'notes': notes,
        'processingStatus': 'pending', // pending, processing, completed
        'analysisResults': null, // Will be populated after ML processing
      };

      // Save image metadata to Firestore
      DocumentReference docRef = await _images.add(imageData);

      // Update the image data with the document ID
      await docRef.update({'id': docRef.id});
      imageData['id'] = docRef.id;

      // Update the appropriate image list based on user type
      if (_user.isAnonymous) {
        await _users.doc(_user.uid).update({
          'sessionImages': FieldValue.arrayUnion([docRef.id]),
        });
      } else {
        await _users.doc(_user.uid).update({
          'images': FieldValue.arrayUnion([docRef.id]),
        });
      }

      return imageData;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Get all images for the current user
  Future<List<Map<String, dynamic>>> getUserImages({int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user data to check if anonymous and get session info
      final userData = await _users.doc(user.uid).get();
      final userDataMap = userData.data() as Map<String, dynamic>?;

      if (userDataMap?['isAnonymous'] == true) {
        // For anonymous users, get images from the current session only
        QuerySnapshot querySnapshot;
        if (userDataMap?['sessionImages'] != null) {
          querySnapshot =
              await _images
                  .where(
                    FieldPath.documentId,
                    whereIn: userDataMap!['sessionImages'],
                  )
                  .orderBy('uploadTime', descending: true)
                  .limit(limit)
                  .get();
        } else {
          // If no session images yet, return empty list
          return [];
        }

        return querySnapshot.docs.map((doc) {
          return doc.data() as Map<String, dynamic>;
        }).toList();
      } else {
        // For regular users, get all their images
        QuerySnapshot querySnapshot =
            await _images
                .where('userId', isEqualTo: user.uid)
                .orderBy('uploadTime', descending: true)
                .limit(limit)
                .get();

        return querySnapshot.docs.map((doc) {
          return doc.data() as Map<String, dynamic>;
        }).toList();
      }
    } catch (e) {
      print('Error getting user images: $e');
      throw Exception('Failed to get user images: $e');
    }
  }

  // Get images with a specific status (pending, processing, completed)
  Future<List<Map<String, dynamic>>> getImagesByStatus(
    String status, {
    int limit = 10,
  }) async {
    try {
      QuerySnapshot querySnapshot =
          await _images
              .where('userId', isEqualTo: _user.uid)
              .where('processingStatus', isEqualTo: status)
              .orderBy('uploadTime', descending: true)
              .limit(limit)
              .get();

      return querySnapshot.docs.map((doc) {
        return doc.data() as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      print('Error getting images by status: $e');
      throw Exception('Failed to get images by status: $e');
    }
  }

  // Update image processing status and analysis results
  Future<void> updateImageAnalysis(
    String imageId,
    String status,
    Map<String, dynamic>? results,
  ) async {
    try {
      await _images.doc(imageId).update({
        'processingStatus': status,
        'analysisResults': results,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating image analysis: $e');
      throw Exception('Failed to update image analysis: $e');
    }
  }

  // Delete a single image
  Future<void> deleteImage(String imageId) async {
    try {
      // Get the image document
      DocumentSnapshot imageDoc = await _images.doc(imageId).get();
      if (!imageDoc.exists) {
        throw Exception('Image not found');
      }

      Map<String, dynamic> imageData = imageDoc.data() as Map<String, dynamic>;
      String? plantId = imageData['plantId'] as String?;

      // Verify user owns the image
      if (imageData['userId'] != _user.uid) {
        // Check if user is from same IP address (for guest sessions)
        final userData = await _users.doc(_user.uid).get();
        final userDataMap = userData.data() as Map<String, dynamic>?;

        final imageUserData = await _users.doc(imageData['userId']).get();
        final imageUserDataMap = imageUserData.data() as Map<String, dynamic>?;

        bool sameIpAccess = false;
        if (userDataMap?['ipAddress'] != null &&
            imageUserDataMap?['ipAddress'] != null &&
            userDataMap!['ipAddress'] == imageUserDataMap!['ipAddress']) {
          sameIpAccess = true;
        }

        if (!sameIpAccess) {
          throw Exception('Not authorized to delete this image');
        }
      }

      // First, check if this is the last image for the plant
      bool isLastImage = false;
      if (plantId != null) {
        final plantImages =
            await _images.where('plantId', isEqualTo: plantId).get();

        isLastImage = plantImages.docs.length <= 1;
      }

      // If it's the last image, delete the plant first (this is faster)
      if (isLastImage && plantId != null) {
        // Remove from user's plants list first
        await _users.doc(_user.uid).update({
          'plants': FieldValue.arrayRemove([plantId]),
        });

        // Delete plant document
        await _plants.doc(plantId).delete();
      }

      // Delete from Firestore first to ensure the operation completes
      await _images.doc(imageId).delete();

      // Now update user document
      if (imageData['userId'] == _user.uid) {
        // For regular users, remove from images array
        await _users.doc(_user.uid).update({
          'images': FieldValue.arrayRemove([imageId]),
        });
      }

      // Check if user is anonymous (guest)
      final userData = await _users.doc(_user.uid).get();
      final userDataMap = userData.data() as Map<String, dynamic>?;

      if (userDataMap?['isAnonymous'] == true) {
        // For anonymous users, remove from sessionImages
        await _users.doc(_user.uid).update({
          'sessionImages': FieldValue.arrayRemove([imageId]),
        });

        // Also find other users with same IP to update their sessionImages
        final sameIpUsers =
            await _users
                .where('ipAddress', isEqualTo: userDataMap!['ipAddress'])
                .where('isAnonymous', isEqualTo: true)
                .get();

        for (var doc in sameIpUsers.docs) {
          if (doc.id != _user.uid) {
            await _users.doc(doc.id).update({
              'sessionImages': FieldValue.arrayRemove([imageId]),
            });
          }
        }
      }

      // Delete from Storage last and with timeouts
      try {
        await _storage
            .ref(imageData['storagePath'])
            .delete()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                print('Storage deletion timed out, continuing with operation');
                return;
              },
            );
      } catch (storageError) {
        // If the file doesn't exist, continue with the deletion process
        if (storageError.toString().contains('object-not-found') ||
            storageError.toString().contains('Not Found')) {
          print('Warning: Storage file not found, continuing with deletion');
        } else {
          // Log but continue
          print('Error deleting from storage: $storageError');
        }
      }

      // If we didn't delete the plant already (not the last image), check if we need to
      if (!isLastImage && plantId != null) {
        final plantImages =
            await _images.where('plantId', isEqualTo: plantId).get();

        if (plantImages.docs.isEmpty) {
          // This was the last image after all (maybe another user deleted one)
          await _plants.doc(plantId).delete();

          // Remove from user's plants list
          await _users.doc(_user.uid).update({
            'plants': FieldValue.arrayRemove([plantId]),
          });
        }
      }
    } catch (e) {
      print('Error deleting image: $e');
      throw Exception('Failed to delete image: $e');
    }
  }
}
