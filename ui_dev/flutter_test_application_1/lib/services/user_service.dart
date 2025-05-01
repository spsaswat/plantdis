import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the users collection reference
  CollectionReference get _users => _firestore.collection('users');

  // Create or update user data in Firestore
  Future<void> createOrUpdateUser(
    User user, {
    Map<String, dynamic>? additionalData,
    String? ipAddress,
  }) async {
    final userData = {
      'uid': user.uid,
      'email': user.email,
      'isAnonymous': user.isAnonymous,
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
      'creationTime': user.metadata.creationTime?.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
      'ipAddress': ipAddress,
      'lastLoginMethod':
          user.providerData.isNotEmpty
              ? user.providerData.first.providerId
              : 'anonymous',
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

  // Get user's IP address
  Future<String> getUserIpAddress() async {
    try {
      // Make a request to an IP address service
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        return response.body;
      }
      throw Exception('Failed to get IP address');
    } catch (e) {
      print('Error getting IP address: $e');
      return 'unknown';
    }
  }

  // Get guest session data
  Future<Map<String, dynamic>> getGuestSessionData(String uid) async {
    try {
      final userData = await getUserData(uid);
      if (userData == null) {
        throw Exception('User data not found');
      }

      // For guests, we want to only show data from their IP address
      if (userData['isAnonymous'] == true) {
        final currentIp = await getUserIpAddress();

        // Query all guest users with the same IP
        final guestQuery =
            await _users
                .where('isAnonymous', isEqualTo: true)
                .where('ipAddress', isEqualTo: currentIp)
                .get();

        // Combine all images from guests with same IP
        List<String> allImages = [];
        for (var doc in guestQuery.docs) {
          final guestData = doc.data() as Map<String, dynamic>;
          if (guestData['images'] != null) {
            allImages.addAll((guestData['images'] as List).cast<String>());
          }
        }

        // Return session-specific data
        return {
          ...userData,
          'sessionImages': allImages,
          'sessionId': '${currentIp}_${DateTime.now().toIso8601String()}',
          'sharedSession': guestQuery.docs.length > 1,
        };
      }

      return userData;
    } catch (e) {
      print('Error getting guest session data: $e');
      throw Exception('Failed to get guest session data: $e');
    }
  }

  // Link accounts with same IP
  Future<void> linkAccountsByIp(User currentUser) async {
    try {
      // Get current user's data
      final currentUserData = await getUserData(currentUser.uid);
      if (currentUserData == null || currentUserData['ipAddress'] == null) {
        return;
      }

      // For guests, we only link with other guest accounts
      if (currentUser.isAnonymous) {
        final querySnapshot =
            await _users
                .where('ipAddress', isEqualTo: currentUserData['ipAddress'])
                .where('uid', isNotEqualTo: currentUser.uid)
                .where('isAnonymous', isEqualTo: true)
                .get();

        // If found other guest users with same IP, merge their data
        for (var doc in querySnapshot.docs) {
          final otherUserData = doc.data() as Map<String, dynamic>;

          // Merge images for the session
          if (otherUserData['images'] != null) {
            await _users.doc(currentUser.uid).update({
              'sessionImages': FieldValue.arrayUnion(
                otherUserData['images'] as List,
              ),
            });
          }
        }
      } else {
        // For non-guest users, proceed with normal account linking
        final querySnapshot =
            await _users
                .where('ipAddress', isEqualTo: currentUserData['ipAddress'])
                .where('uid', isNotEqualTo: currentUser.uid)
                .get();

        for (var doc in querySnapshot.docs) {
          final otherUserData = doc.data() as Map<String, dynamic>;

          if (otherUserData['images'] != null) {
            await _users.doc(currentUser.uid).update({
              'images': FieldValue.arrayUnion(otherUserData['images'] as List),
            });
          }
        }
      }
    } catch (e) {
      print('Error linking accounts by IP: $e');
    }
  }
}
