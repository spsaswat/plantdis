import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'main.dart';

class ResultPage extends StatefulWidget {
  final File image;
  final String result;
  final Future<void> Function(File, String, String) saveResultToFirestore;

  ResultPage({required this.image, required this.result, required this.saveResultToFirestore});

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final _feedbackController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitFeedback() async {
    setState(() {
      _isLoading = true;
    });
    try {
      Fluttertoast.showToast(msg: 'Submitting feedback...');
      await widget.saveResultToFirestore(widget.image, widget.result, _feedbackController.text);
      Fluttertoast.showToast(msg: 'Feedback submitted successfully');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyAppHome(userId: '',)));
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to submit feedback: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _goBack() async {
    setState(() {
      _isLoading = true;
    });
    try {
      Fluttertoast.showToast(msg: 'Saving result...');
      await widget.saveResultToFirestore(widget.image, widget.result, _feedbackController.text);
      Fluttertoast.showToast(msg: 'Result saved successfully');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyAppHome(userId: '',)));
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to save result: $e');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyAppHome(userId: '',)));
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Column(
                  children: [
                    _isLoading
                        ? CircularProgressIndicator()
                        : FloatingActionButton.extended(
                      onPressed: _submitFeedback,
                      backgroundColor: const Color(0xffF8DC27),
                      label: Text(
                        'Submit Feedback',
                        style: TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ),
                    SizedBox(height: 10),
                    _isLoading
                        ? SizedBox.shrink()
                        : FloatingActionButton(
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