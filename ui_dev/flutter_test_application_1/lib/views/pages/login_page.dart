import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/services/auth_service.dart';
import 'package:flutter_test_application_1/views/widget_tree.dart';
import 'package:flutter_test_application_1/views/widgets/google_sign_in_button.dart';
import 'package:flutter_test_application_1/views/widgets/hero_widget.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController controllerEmail = TextEditingController();
  TextEditingController controllerPwd = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleSignInLoading = false;
  String? _errorMessage;

  final _authService = AuthService();

  @override
  void dispose() {
    super.dispose();
    controllerEmail.dispose();
    controllerPwd.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(50.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FractionallySizedBox(
                    widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 25.0,
                      children: [
                        HeroWidget(title: "Login"),

                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        TextField(
                          controller: controllerEmail,
                          decoration: InputDecoration(
                            hintText: "Username / Email",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          onEditingComplete: () {
                            setState(() {});
                          },
                        ),

                        TextField(
                          controller: controllerPwd,
                          decoration: InputDecoration(
                            hintText: "Password",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          obscureText: true,
                          onEditingComplete: () {
                            setState(() {});
                          },
                        ),

                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            textStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _isLoading ? null : () => onLoginPressed(),
                          child:
                              _isLoading
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text("Get Started"),
                        ),

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

  Future<void> onLoginPressed() async {
    if (controllerEmail.text.isEmpty || controllerPwd.text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter both email and password";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmailPassword(
        controllerEmail.text,
        controllerPwd.text,
      );

      // Check if widget is still mounted
      if (mounted) {
        navigateToHome();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Successful"),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      // Check if widget is still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Failed: ${e.toString()}"),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
