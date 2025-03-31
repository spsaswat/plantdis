import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/avatar_picker_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test_application_1/utils/web_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

// TODO: Implement user settings and preferences
class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userName;
  String? _userEmail;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userData = await _firestore.collection('users').doc(user.uid).get();
      if (userData.exists) {
        setState(() {
          _userName = userData.data()?['name'] ?? 'User';
          _userEmail = user.email;
          _avatarUrl =
              userData.data()?['avatarUrl'] ?? 'assets/avatars/botanist.png';
        });
      } else {
        // Create user document if it doesn't exist
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName ?? 'User',
          'email': user.email,
          'avatarUrl': 'assets/avatars/botanist.png',
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _userName = user.displayName ?? 'User';
          _userEmail = user.email;
          _avatarUrl = 'assets/avatars/botanist.png';
        });
      }
    }
  }

  Future<void> _updateAvatar(String newAvatarUrl) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'avatarUrl': newAvatarUrl,
      });
      setState(() {
        _avatarUrl = newAvatarUrl;
      });
    }
  }

  void _showAvatarPicker() {
    showDialog(
      context: context,
      builder:
          (context) => AvatarPickerDialog(
            currentAvatarUrl: _avatarUrl,
            onAvatarSelected: _updateAvatar,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              GestureDetector(
                onTap: _showAvatarPicker,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage(
                        _avatarUrl ?? 'assets/avatars/botanist.png',
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                _userName ?? 'Loading...',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                _userEmail ?? '',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 32),
              _buildCreditsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avatar Credits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Special thanks to the following artists for their beautiful avatars:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            _buildCreditItem(
              'Botanist Avatar',
              'Created by dDara - Flaticon',
              'assets/avatars/botanist.png',
            ),
            _buildCreditItem(
              'Farmer Avatar',
              'Created by Amethyst prime - Flaticon',
              'assets/avatars/farmer.png',
            ),
            _buildCreditItem(
              'Gardener Avatar',
              'Created by Umeicon - Flaticon',
              'assets/avatars/gardener.png',
            ),
            _buildCreditItem(
              'Plant Character',
              'Created by jocularityart - Flaticon',
              'assets/avatars/plant.png',
            ),
            _buildCreditItem(
              'Forest Ranger Avatar',
              'Created by Febrian Hidayat - Flaticon',
              'assets/avatars/forest ranger.png',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditItem(String title, String credit, String imagePath) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Image.asset(imagePath, width: 40, height: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  credit,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
