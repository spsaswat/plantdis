import 'package:PlantDis/register_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  void _checkUserExists() async {
    setState(() {
      _isLoading = true;
    });

    bool userFound = false;

    try {
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text)
          .get();

      final List<DocumentSnapshot> documents = result.docs;

      if (documents.isNotEmpty) {
        userFound = true;
        // User exists, navigate to main page
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => MyAppHome(userId: documents.first.id,)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking user existence: $e')),
        );
      }
    }

    // Delay for 1 second before showing no user found message if user not found
    Future.delayed(Duration(seconds: 1), () {
      if (!userFound) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No user found with this email')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    });

    if (userFound) {
      setState(() {
        _isLoading = false;
      });
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

  void _signInAsGuest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.green[600],
        scaffoldBackgroundColor: Colors.lightGreenAccent,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Sign In'),
          backgroundColor: Colors.green[600],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(height: 40), // Add some space on top
                  Image.asset(
                    'assets/images/icon10241.png',
                    width: 200, // Adjust the width as needed
                    height: 200, // Adjust the height as needed
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                        labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.grey,),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white,
                          width: 2.0,
                        )
                      ),
                      focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                    color: Colors.white,
                      width: 2.0,
                    ),
                  ),

                    ),
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
                      : Column(
                    children: [
                      ElevatedButton(
                        onPressed: _sendVerificationCode,
                        child: Text('Send Verification Link'),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _signInAsGuest,
                        child: Text('Sign in as Guest'),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _checkUserExists,
                        child: Text('Login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
