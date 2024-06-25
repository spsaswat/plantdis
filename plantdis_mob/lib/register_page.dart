import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _educationLevel = 'not selected';
  String _industrialArea = 'not selected';
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _checkLoggedInUser();
  }

  void _checkLoggedInUser() async {
    User? user = _auth.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    } else {
      _emailController.clear();
    }
    print('Current user: ${user?.email}');
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: 'some_default_password', // This can be a fixed value if you're using email link sign-in
        );

        String userId = userCredential.user!.uid;

        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'name': _nameController.text,
          'email': _emailController.text,
          'educationLevel': _educationLevel,
          'industrialArea': _industrialArea,
          'results': [], // initialize results field as an empty array
          'images': []
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration successful!')));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyAppHome(userId: '',)));
      } catch (e) {
        print('Error registering: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error registering: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _educationLevel,
                decoration: InputDecoration(labelText: 'Education Level'),
                items: ['High School', 'Undergraduate', 'Postgraduate', 'Others', 'not selected'].map((level) {
                  return DropdownMenuItem(value: level, child: Text(level));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _educationLevel = value!;
                  });
                },
              ),
              DropdownButtonFormField<String>(
                value: _industrialArea,
                decoration: InputDecoration(labelText: 'Industrial Area'),
                items: ['Finance', 'IT', 'Consulting', 'Others', 'not selected'].map((area) {
                  return DropdownMenuItem(value: area, child: Text(area));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _industrialArea = value!;
                  });
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _register,
                child: Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
