import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'main.dart'; // Import MyAppHome

class ResultPage extends StatefulWidget {
  final File image;
  final String result;
  final Future<void> Function(File, String, String) saveResultToFirestore; // Add this

  ResultPage({required this.image, required this.result, required this.saveResultToFirestore});

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final _feedbackController = TextEditingController();

  Future<void> _submitFeedback() async {
    try {
      await widget.saveResultToFirestore(widget.image, widget.result, _feedbackController.text);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Feedback submitted successfully')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyAppHome(userId: '',)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit feedback: $e')));
    }
  }

  Future<void> _goBack() async {
    try {
      await widget.saveResultToFirestore(widget.image, widget.result, _feedbackController.text);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyAppHome(userId: '',)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save result: $e')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyAppHome(userId: '',)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreenAccent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  children: [
                    Container(
                      margin: EdgeInsets.all(20),
                      child: Image.file(widget.image, width: 300, height: 200, fit: BoxFit.cover),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        widget.result,
                        style: TextStyle(fontSize: 24, color: Colors.black54, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Noticed some issue? Help us improve our model.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: TextField(
                        controller: _feedbackController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white60,
                          hintText: 'Write your feedback here...',
                          hintStyle: TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20), // Add some space
                Column(
                  children: [
                    FloatingActionButton.extended(
                      onPressed: _submitFeedback,
                      backgroundColor: const Color(0xffF8DC27),
                      label: Text(
                        'Submit Feedback',
                        style: TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ),
                    SizedBox(height: 10),
                    FloatingActionButton(
                      onPressed: _goBack,
                      child: Icon(Icons.arrow_back),
                      backgroundColor: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
