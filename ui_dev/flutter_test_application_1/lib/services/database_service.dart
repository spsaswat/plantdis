import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class DatabaseService {
  final User _user = FirebaseAuth.instance.currentUser!;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> uploadImage(XFile xfileImage) async {
    File image = File(xfileImage.path);
    Reference reference = _storage.ref().child(
      "user_images/${_user.isAnonymous ? "Anon" : "Registered"}/${_user.uid}/",
    );

    UploadTask uploadTask = reference
        .child(
          "img_${await reference.listAll().then((value) async => value.items.length)}.jpg",
        )
        .putFile(image, SettableMetadata(contentType: "image/jpeg"));

    uploadTask.snapshotEvents.listen((TaskSnapshot taskSnapshot) {
      switch (taskSnapshot.state) {
        case TaskState.running:
          final progress =
              100.0 * (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes);
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
  }

  Future<List> getImages() async {
    Reference reference = _storage.ref().child(
      "user_images/${_user.isAnonymous ? "Anon" : "Registered"}/${_user.uid}/",
    );

    ListResult images = await reference.listAll();
    
    return images.items;
  }
}
