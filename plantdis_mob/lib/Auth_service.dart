import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'dart:developer' as developer;
import 'dart:io';

import 'main.dart';
import 'register_page.dart';

class AuthService {
  final _firebaseAuth = firebase_auth.FirebaseAuth.instance;

  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  String get userName =>
      isAuthenticated ? _firebaseAuth.currentUser!.email ?? '' : '';

  Future<void> sendEmailLink({required String email}) async {
    developer.log('sendEmailLink[$email]');
    final actionCodeSettings = firebase_auth.ActionCodeSettings(
      url: 'https://plantdis.page.link/mVFa',
      handleCodeInApp: true,
      androidPackageName: 'com.spsaswat.plantdis.plantdis_mob',
      iOSBundleId: 'com.example.ios',
      androidInstallApp: true,
      androidMinimumVersion: '12',
    );
    await _firebaseAuth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email);
  }

  Future<void> retrieveDynamicLinkAndSignIn({required bool fromColdState}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email');
    if (email == null || email.isEmpty) return;

    PendingDynamicLinkData? dynamicLinkData;
    if (fromColdState) {
      dynamicLinkData = await FirebaseDynamicLinks.instance.getInitialLink();
    } else {
      dynamicLinkData = await FirebaseDynamicLinks.instance.onLink.first;
    }

    Uri? deepLink = dynamicLinkData?.link;
    if (deepLink != null) {
      bool validLink = _firebaseAuth.isSignInWithEmailLink(deepLink.toString());

      /// Password-less hack for IOS
      if (!validLink && Platform.isIOS) {
        ClipboardData? data = await Clipboard.getData('text/plain');
        if (data != null) {
          final linkData = data.text ?? '';
          final link = Uri.parse(linkData).queryParameters['link'] ?? "";
          validLink = _firebaseAuth.isSignInWithEmailLink(link);
          if (validLink) {
            deepLink = Uri.parse(link);
          }
        }
      }
      /// End - Password-less hack for IOS

      if (validLink) {
        final userCredential = await _firebaseAuth.signInWithEmailLink(
          email: email,
          emailLink: deepLink.toString(),
        );
        if (userCredential.user != null) {
          // Check if user is registered and navigate accordingly
          final isRegistered = await _checkUserRegistered(userCredential.user!.uid);
          if (isRegistered) {
            Get.offAll(() => MyAppHome(userId: '',));
          } else {
            Get.offAll(() => RegisterPage());
          }
        }
      }
    }
  }

  Future<bool> _checkUserRegistered(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.exists;
  }
}
