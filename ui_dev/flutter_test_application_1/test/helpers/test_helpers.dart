// test/helpers/test_helpers.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:flutter_test_application_1/firebase_options.dart';

/// Provides convenience helpers for login/register page tests.
class TestHelpers {
  static final auth = TestFirebaseAuth();

  /// Creates a local Firebase app and replaces authentication at its platform
  /// boundary. No Firebase backend or native plugin is contacted.
  static Future<void> setupFirebaseMocks() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestFirebaseCoreHostApi.setUp(_TestFirebaseCore());
    FirebaseAuthPlatform.instance = auth;
    GoogleSignInPlatform.instance = _TestGoogleSignIn();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  /// Wraps the widget under test with MaterialApp.
  static Widget createTestApp(Widget child) {
    return MaterialApp(home: child);
  }

  /// Pumps the widget into the test environment and settles one frame.
  static Future<void> pumpWithSetup(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(createTestApp(child));
    await tester.pump();
  }
}

class TestFirebaseAuth extends FirebaseAuthPlatform {
  UserPlatform? user;
  Future<UserCredentialPlatform> Function(String email, String password)?
  onSignIn;
  Future<UserCredentialPlatform> Function(String email, String password)?
  onRegister;
  Future<UserCredentialPlatform> Function()? onAnonymous;

  void reset() {
    user = null;
    onSignIn = null;
    onRegister = null;
    onAnonymous = null;
  }

  @override
  Future<UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) =>
      onSignIn?.call(email, password) ??
      Future.error(StateError('Configure onSignIn in this test'));

  @override
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) =>
      onRegister?.call(email, password) ??
      Future.error(StateError('Configure onRegister in this test'));

  @override
  Future<UserCredentialPlatform> signInAnonymously() =>
      onAnonymous?.call() ??
      Future.error(FirebaseAuthException(code: 'operation-not-allowed'));

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream.value(null);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream.value(null);
}

class _TestGoogleSignIn extends GoogleSignInPlatform {
  @override
  Future<void> init(InitParameters params) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestFirebaseCore extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions options,
  ) async => CoreInitializeResponse(
    name: appName,
    options: options,
    pluginConstants: {},
  );
}
