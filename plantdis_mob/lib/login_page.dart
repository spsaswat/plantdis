import 'package:PlantDis/register_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';


import 'main.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: 'some_default_password');
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  void _checkUserExists() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text)
          .get();

      final List<DocumentSnapshot> documents = result.docs;

      if (documents.isNotEmpty) {
        // Sign in the user
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text, // This should match the password used during registration
        );

        // User exists, navigate to main page with user ID
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MyAppHome(userId: userCredential.user!.uid)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No user found with this email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking user existence: $e')),
        );
      }
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
                      ///for now just use guest mode
                      // ElevatedButton(
                      //   onPressed: _sendVerificationCode,
                      //   child: Text('Send Verification Link'),
                      // ),
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
