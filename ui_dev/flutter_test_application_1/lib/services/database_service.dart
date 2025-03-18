import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DatabaseService {
  final User _user = FirebaseAuth.instance.currentUser!;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> uploadImage(XFile image) async {
    int currIdx = 0;
    File _image = File(image.path);
    Reference reference = _storage.ref().child(
      "user_images/${_user.isAnonymous ? "Anon" : _user.uid}/",
    );

    UploadTask uploadTask = reference
        .child(
          "img_${await reference.listAll().then((value) async => value.items.length)}.jpg",
        )
        .putFile(_image, SettableMetadata(contentType: "image/jpeg"));

    uploadTask.snapshotEvents.listen((TaskSnapshot taskSnapshot) {
      switch (taskSnapshot.state) {
        case TaskState.running:
          final progress =
              100.0 * (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes);
          print("Upload is $progress% complete.");
          break;
        case TaskState.paused:
          print("Upload is paused.");
          break;
        case TaskState.canceled:
          print("Upload was canceled");
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
}
