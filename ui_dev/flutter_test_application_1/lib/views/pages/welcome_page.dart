import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:flutter_test_application_1/services/auth_service.dart';
import 'package:flutter_test_application_1/views/pages/login_page.dart';
import 'package:flutter_test_application_1/views/pages/register_page.dart';
import 'package:flutter_test_application_1/views/widget_tree.dart';
import 'package:flutter_test_application_1/views/widgets/google_sign_in_button.dart';
import 'package:lottie/lottie.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isGoogleSignInLoading = false;
  bool _isGuestSignInLoading = false;
  String? _errorMessage;
  final _authService = AuthService();

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
                      spacing: 10,
                      children: [
                        Lottie.asset(
                          "assets/lotties/welcome-leaf.json",
                          height: 250.0,
                          width: double.infinity,
                        ),

                        Text("PlantDis", style: KTextStyle.appTitle),

                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            textStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return LoginPage();
                                },
                              ),
                            );
                          },
                          child: Text("Login"),
                        ),

                        SizedBox(height: 12),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            textStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return RegisterPage();
                                },
                              ),
                            );
                          },
                          child: Text("Register"),
                        ),

                        SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
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

                        SizedBox(height: 16),

                        GoogleSignInButton(
                          isLoading: _isGoogleSignInLoading,
                          onSignInComplete: (isSuccess, errorMessage) {
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

                        SizedBox(height: 16),

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            textStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          icon: Icon(Icons.person_outline),
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
                                  : Text("Continue as Guest"),
                          onPressed:
                              _isGuestSignInLoading ? null : _signInAsGuest,
                        ),
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
      await _authService.signInAnonymously();
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
          return WidgetTree();
        },
      ),
      (route) => false,
    );
  }
}
