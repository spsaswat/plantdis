import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test_application_1/services/auth_service.dart';

class GoogleSignInButton extends StatelessWidget {
  final Function(bool isSuccess, String? errorMessage) onSignInComplete;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onSignInComplete,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      onPressed: isLoading ? null : () => _signInWithGoogle(context),
      child:
          isLoading
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/google_logo.svg',
                    height: 24,
                    width: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
    );
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final AuthService authService = AuthService();
      final userCredential = await authService.signInWithGoogle();

      if (userCredential != null) {
        onSignInComplete(true, null);
      } else {
        onSignInComplete(false, 'Google sign-in was cancelled');
      }
    } catch (e) {
      onSignInComplete(false, e.toString());
    }
  }
}
