import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
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

  @override
  void initState() {
    super.initState();
    _checkDynamicLinks();
  }

  void _checkDynamicLinks() async {
    final PendingDynamicLinkData? data = await FirebaseDynamicLinks.instance.getInitialLink();
    _handleDynamicLink(data);

    FirebaseDynamicLinks.instance.onLink.listen((PendingDynamicLinkData dynamicLinkData) {
      _handleDynamicLink(dynamicLinkData);
    }).onError((error) {
      print('onLink error');
      print(error.message);
    });
  }

  void _handleDynamicLink(PendingDynamicLinkData? data) async {
    final Uri? deepLink = data?.link;

    if (deepLink != null) {
      if (_auth.isSignInWithEmailLink(deepLink.toString())) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? email = prefs.getString('email');
        if (email != null) {
          try {
            UserCredential userCredential = await _auth.signInWithEmailLink(email: email, emailLink: deepLink.toString());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully signed in!')));
            print('Successfully signed in with email link!');
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error signing in with email link: $e')));
            print('Error signing in with email link: $e');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No email found for sign in')));
        }
      }
    }
  }

  void _sendVerificationCode() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('Attempting to send email to: ${_emailController.text}');
        await _auth.sendSignInLinkToEmail(
          email: _emailController.text,
          actionCodeSettings: ActionCodeSettings(
            url: 'https://plantdis.page.link/mVFa', // use dynamic id
            handleCodeInApp: true,
            iOSBundleId: 'com.example.ios',
            androidPackageName: 'com.spsaswat.plantdis.plantdis_mob',
            androidInstallApp: true,
            androidMinimumVersion: '12',
          ),
        );

        //save the email add
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', _emailController.text);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email has been sent!'),
          ),
        );
        print('Email sent successfully.');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: $e'),
          ),
        );
        print('Failed to send email: $e');
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
