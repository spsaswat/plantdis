import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the users collection reference
  CollectionReference get _users => _firestore.collection('users');

  // Create or update user data in Firestore
  Future<void> createOrUpdateUser(
    User user, {
    Map<String, dynamic>? additionalData,
  }) async {
    final userData = {
      'uid': user.uid,
      'email': user.email,
      'isAnonymous': user.isAnonymous,
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
      'creationTime': user.metadata.creationTime?.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...?additionalData,
    };

    await _users.doc(user.uid).set(userData, SetOptions(merge: true));
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final docSnapshot = await _users.doc(uid).get();
    return docSnapshot.data() as Map<String, dynamic>?;
  }

  // Update user data
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Convert anonymous account to permanent account
  Future<void> convertAnonymousAccount(String email, String password) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || !currentUser.isAnonymous) {
        throw Exception('No anonymous user signed in');
      }

      // Create credentials
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      // Link anonymous account with email/password
      final userCredential = await currentUser.linkWithCredential(credential);

      // Update user data in Firestore
      await createOrUpdateUser(
        userCredential.user!,
        additionalData: {
          'email': email,
          'isAnonymous': false,
          'conversionTime': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      throw Exception('Failed to convert anonymous account: ${e.toString()}');
    }
  }

  // Delete user data
  Future<void> deleteUserData(String uid) async {
    await _users.doc(uid).delete();
  }
}
