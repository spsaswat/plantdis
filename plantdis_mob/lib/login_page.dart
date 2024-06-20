import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_validator/email_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  void _sendVerificationCode() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _auth.sendSignInLinkToEmail(
          email: _emailController.text,
          actionCodeSettings: ActionCodeSettings(
            url: 'https://yourapp.page.link/verify',
            handleCodeInApp: true,
            iOSBundleId: 'com.example.ios',
            androidPackageName: 'com.example.android',
            androidInstallApp: true,
            androidMinimumVersion: '12',
          ),
        );

        // 保存电子邮件地址
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', _emailController.text);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email has been sent!'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: $e'),
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign In'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  } else if (!EmailValidator.validate(value)) {
                    return 'Please enter a valid email';
                  } else if (!value.endsWith('.edu.au')) {
                    return 'Only educational emails are allowed';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _sendVerificationCode,
                child: Text('Send Verification Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
