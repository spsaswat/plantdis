import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:flutter_test_application_1/services/auth_service.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';
import 'package:flutter_test_application_1/views/pages/login_page.dart';
import 'package:flutter_test_application_1/views/pages/register_page.dart';
import 'package:flutter_test_application_1/views/widget_tree.dart';
import 'package:flutter_test_application_1/views/widgets/google_sign_in_button.dart';
import 'package:lottie/lottie.dart';

import '../../firebase_options.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  static bool isFirebaseInitialized = false;
  bool _isGoogleSignInLoading = false;
  bool _isGuestSignInLoading = false;
  /// When false: hide Login / Register / Google and use fully local guest (no Firebase).
  /// Linux does not show this switch (always local-only welcome).
  bool _saveDataOnCloud = true;
  String? _errorMessage;
  AuthService? _authServiceInstance;
  AuthService? get _authService => _authServiceInstance ??= AuthService();
  final _localGuestService = LocalGuestService();

  /// Login / Register / Google — hidden when cloud save is off or unsupported (e.g. Linux).
  bool get _showFirebaseAuthOptions =>
      LocalGuestService.supportsFirebaseCloudToggle && _saveDataOnCloud;

  bool get _useLocalGuestWithoutFirebase {
    if (LocalGuestService.isLinux) return true;
    if (!LocalGuestService.supportsFirebaseCloudToggle) return true;
    return !_saveDataOnCloud;
  }

  Future<void> initFireBase() async {
    if (isFirebaseInitialized) {
      return;
    }
    isFirebaseInitialized = true;
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FractionallySizedBox(
                    widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 15,
                      children: [
                        Lottie.asset(
                          "assets/lotties/welcome-leaf.json",
                          height: 250.0,
                          width: double.infinity,
                        ),

                        const Text("PlantDis", style: KTextStyle.appTitle),

                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        if (_showFirebaseAuthOptions) ...[
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () async {
                              await initFireBase();
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return const LoginPage();
                                  },
                                ),
                              );
                            },
                            child: const Text("Login"),
                          ),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: () async {
                              await initFireBase();
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return const RegisterPage();
                                  },
                                ),
                              );
                            },
                            child: const Text("Register"),
                          ),

                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Text(
                                  "OR",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),

                          GoogleSignInButton(
                            isLoading: _isGoogleSignInLoading,
                            onSignInComplete: (isSuccess, errorMessage) async {
                              await initFireBase();
                              if (isSuccess) {
                                navigateToHome();
                              } else {
                                setState(() {
                                  _isGoogleSignInLoading = false;
                                  _errorMessage = errorMessage;
                                });
                              }
                            },
                          ),
                        ],

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          icon: const Icon(Icons.person_outline),
                          label:
                              _isGuestSignInLoading
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  )
                                  : const Text("Continue as Guest"),
                          onPressed:
                              _isGuestSignInLoading ? null : _signInAsGuest,
                        ),

                        if (LocalGuestService.supportsFirebaseCloudToggle) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Switch(
                                  value: _saveDataOnCloud,
                                  onChanged: (v) {
                                    setState(() => _saveDataOnCloud = v);
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    'Save data on cloud',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.85),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInAsGuest() async {
    setState(() {
      _isGuestSignInLoading = true;
      _errorMessage = null;
    });

    try {
      // Linux, unsupported platforms, or cloud save off: fully local without Firebase.
      if (_useLocalGuestWithoutFirebase) {
        _localGuestService.setLocalGuestMode(true);
      } else {
        await initFireBase();
        _localGuestService.setLocalGuestMode(false);
        await _authService!.signInAnonymously();
      }
      navigateToHome();
    } catch (e) {
      setState(() {
        _isGuestSignInLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) {
          return const WidgetTree();
        },
      ),
      (route) => false,
    );
  }
}
