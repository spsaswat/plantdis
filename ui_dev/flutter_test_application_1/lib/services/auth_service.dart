import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test_application_1/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;
  final UserService _userService = UserService();

  AuthService() {
    // Initialize GoogleSignIn with web configuration if needed
    if (kIsWeb) {
      _googleSignIn = GoogleSignIn(
        clientId:
            '748587653216-3fdjn59qrs56gh3qpojkgcna1tuobn4j.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
    } else {
      _googleSignIn = GoogleSignIn();
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Create or update user data in Firestore
      await _userService.createOrUpdateUser(credential.user!);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Create user data in Firestore
      await _userService.createOrUpdateUser(credential.user!);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Begin interactive sign-in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in flow
        return null;
      }

      // Obtain auth details from request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create new credential for user
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Create or update user data in Firestore
      await _userService.createOrUpdateUser(userCredential.user!);

      return userCredential;
    } catch (e) {
      print('Exception during Google sign in: $e');
      rethrow;
    }
  }

  // Sign in anonymously (Guest Login)
  Future<UserCredential> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();

      // Create or update user data in Firestore with additional guest info
      await _userService.createOrUpdateUser(
        userCredential.user!,
        additionalData: {
          'userType': 'guest',
          'guestSignInTime': FieldValue.serverTimestamp(),
        },
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // Convert anonymous account to permanent account
  Future<void> convertAnonymousToPermament(
    String email,
    String password,
  ) async {
    await _userService.convertAnonymousAccount(email, password);
  }

  // Sign out
  Future<void> signOut() async {
    final user = currentUser;
    if (user != null && user.isAnonymous) {
      // Delete anonymous user data when they sign out
      await _userService.deleteUserData(user.uid);
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Handle Firebase Auth Exceptions
  Exception _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No user found with this email.');
      case 'wrong-password':
        return Exception('Wrong password.');
      case 'email-already-in-use':
        return Exception('The email address is already in use.');
      case 'weak-password':
        return Exception('The password is too weak.');
      case 'invalid-email':
        return Exception('The email address is invalid.');
      case 'operation-not-allowed':
        return Exception(
          'Anonymous sign-in is not enabled. Please enable it in the Firebase Console.',
        );
      default:
        return Exception('An error occurred: ${e.message}');
    }
  }
}
