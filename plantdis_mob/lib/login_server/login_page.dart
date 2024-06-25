import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:email_validator/email_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import '../main.dart';
import '../register_page.dart';
import 'auth_service.dart';


class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _auth = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkDynamicLinks();
  }

  void _checkDynamicLinks() async {
    await _auth.retrieveDynamicLinkAndSignIn(fromColdState: true);
    FirebaseDynamicLinks.instance.onLink.listen((PendingDynamicLinkData? dynamicLinkData) {
      _auth.retrieveDynamicLinkAndSignIn(fromColdState: false);
    }).onError((error) {
      print('onLink error');
      print(error.message);
    });
  }

  void _sendVerificationCode() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _auth.sendEmailLink(email: _emailController.text);
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

  void _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await FirebaseAuth.instance.fetchSignInMethodsForEmail(_emailController.text);
      if (user.isNotEmpty) {
        // User exists, navigate to main page
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyAppHome()));
      } else {
        // New user, send verification email
        _sendVerificationCode();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _signInAsGuest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage()),
    );
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
                child: Text('Send verify link'),
              ),
              SizedBox(height: 20,),
              ElevatedButton(
                onPressed: _signInAsGuest,
                child: Text('Sign in as Guest'),
              ),
              SizedBox(height: 20,),
              ElevatedButton(onPressed: _login, child: Text('login'))
            ],
          ),
        ),
      ),
    );
  }
}
