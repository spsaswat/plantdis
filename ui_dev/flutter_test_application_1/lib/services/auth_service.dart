import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_test_application_1/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final UserService _userService = UserService();

  AuthService() {
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
    } catch (e) {
      print('Error initializing Google Sign In: $e');
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
      // Get IP address before sign in
      final ipAddress = await _userService.getUserIpAddress();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create or update user data in Firestore with IP
      await _userService.createOrUpdateUser(
        credential.user!,
        ipAddress: ipAddress,
      );

      // Link accounts with same IP
      await _userService.linkAccountsByIp(credential.user!);

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
      // Use the new authenticate method for 7.1.1+
      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      // Get authentication for Firebase - using legacy method for compatibility
      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: null, // 7.1.1 doesn't provide accessToken in same way
        idToken: googleAuth.idToken,
      );

      // Get IP address before sign in
      final ipAddress = await _userService.getUserIpAddress();

      // Sign in with credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Create or update user data in Firestore with IP address
      await _userService.createOrUpdateUser(
        userCredential.user!,
        ipAddress: ipAddress,
      );

      // Link accounts with same IP
      await _userService.linkAccountsByIp(userCredential.user!);

      return userCredential;
    } catch (e) {
      print('Exception during Google sign in: $e');
      rethrow;
    }
  }

  // Sign in anonymously (Guest Login)
  Future<UserCredential> signInAnonymously() async {
    try {
      // Get IP address before sign in
      final ipAddress = await _userService.getUserIpAddress();

      final userCredential = await _auth.signInAnonymously();

      // Create or update user data in Firestore with additional guest info and IP
      await _userService.createOrUpdateUser(
        userCredential.user!,
        additionalData: {
          'userType': 'guest',
          'guestSignInTime': FieldValue.serverTimestamp(),
        },
        ipAddress: ipAddress,
      );

      // Link accounts with same IP
      await _userService.linkAccountsByIp(userCredential.user!);

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
