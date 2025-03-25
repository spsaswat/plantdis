import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class DatabaseService {
  final User _user = FirebaseAuth.instance.currentUser!;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reference to the users collection
  CollectionReference get _users => _firestore.collection('users');

  // Reference to the images collection
  CollectionReference get _images => _firestore.collection('images');

  // Upload image to Firebase Storage and save metadata to Firestore
  Future<Map<String, dynamic>> uploadImage(
    XFile image, {
    String? plantType,
    String? notes,
  }) async {
    try {
      // Create a file from the XFile
      File imageFile = File(image.path);

      // Create a unique filename
      String fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Define the storage path - organize by user ID (or anonymous)
      String userFolder = _user.isAnonymous ? "anonymous" : _user.uid;
      String storagePath = "user_images/$userFolder/$fileName";

      // Create a reference to the storage location
      Reference storageRef = _storage.ref().child(storagePath);

      // Upload the file with metadata
      UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: "image/jpeg"),
      );

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
            // Handle unsuccessful uploads
            print("Upload encountered an error");
            break;
          case TaskState.success:
            // Handle successful uploads on complete
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

      // Update user's images list in their profile
      await _users.doc(_user.uid).update({
        'images': FieldValue.arrayUnion([docRef.id]),
      });

      return imageData;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Get all images for the current user
  Future<List<Map<String, dynamic>>> getUserImages({int limit = 10}) async {
    try {
      // Query the images collection for the current user's images
      QuerySnapshot querySnapshot =
          await _images
              .where('userId', isEqualTo: _user.uid)
              .orderBy('uploadTime', descending: true)
              .limit(limit)
              .get();

      // Convert the query results to a List of Maps
      return querySnapshot.docs.map((doc) {
        return doc.data() as Map<String, dynamic>;
      }).toList();
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

  // Delete an image (from both Storage and Firestore)
  Future<void> deleteImage(String imageId) async {
    try {
      // Get the image document
      DocumentSnapshot imageDoc = await _images.doc(imageId).get();
      Map<String, dynamic> imageData = imageDoc.data() as Map<String, dynamic>;

      // Delete from Storage
      await _storage.ref(imageData['storagePath']).delete();

      // Delete from Firestore
      await _images.doc(imageId).delete();

      // Remove from user's images list
      await _users.doc(_user.uid).update({
        'images': FieldValue.arrayRemove([imageId]),
      });
    } catch (e) {
      print('Error deleting image: $e');
      throw Exception('Failed to delete image: $e');
    }
  }
}
