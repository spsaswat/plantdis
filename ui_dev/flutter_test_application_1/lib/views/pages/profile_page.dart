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

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _getUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    try {
      // Get user document from Firestore
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // Create user document if it doesn't exist
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'createdAt': DateTime.now(),
          'plants': [],
          'avatarUrl': 'assets/avatars/farmer.png', // Default avatar
        });
        return {
          'email': user.email,
          'plantsCount': 0,
          'avatarUrl': 'assets/avatars/farmer.png',
        };
      }

      final data = doc.data()!;
      return {
        'email': user.email,
        'plantsCount': (data['plants'] as List?)?.length ?? 0,
        'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        'avatarUrl': data['avatarUrl'] ?? 'assets/avatars/farmer.png',
      };
    } catch (e) {
      print('Error getting user data: $e');
      throw Exception('Failed to load profile');
    }
  }

  Future<void> _updateAvatar(String avatarUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _firestore.collection('users').doc(user.uid).update({
        'avatarUrl': avatarUrl,
      });

      // Refresh the UI
      setState(() {});
    } catch (e) {
      print('Error updating avatar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile picture')),
      );
    }
  }

  void _showAvatarPicker(String? currentAvatarUrl) {
    showDialog(
      context: context,
      builder:
          (context) => AvatarPickerDialog(
            currentAvatarUrl: currentAvatarUrl,
            onAvatarSelected: _updateAvatar,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final userData = snapshot.data!;
          String avatarUrl = userData['avatarUrl'] ?? '';
          bool isNetworkImage = avatarUrl.startsWith('http');

          // Check if we need to use a fallback
          if (avatarUrl.isEmpty || (!isNetworkImage && kIsWeb)) {
            // Try to get fallback from WebUtils for web
            if (kIsWeb) {
              String? fallbackUrl = WebUtils.getFallbackImageUrl('farmer');
              if (fallbackUrl != null) {
                avatarUrl = fallbackUrl;
                isNetworkImage = true; // Data URLs act like network images
              }
            }

            if (avatarUrl.isEmpty) {
              // If still empty, use icon as fallback
              return _buildProfileContent(
                userData,
                Icon(
                  Icons.account_circle,
                  size: 100,
                  color: Colors.blue.shade300,
                ),
              );
            }
          }

          return _buildProfileContent(
            userData,
            GestureDetector(
              onTap: () => _showAvatarPicker(avatarUrl),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        isNetworkImage ? NetworkImage(avatarUrl) : null,
                    child:
                        !isNetworkImage
                            ? Image.asset(
                              avatarUrl,
                              errorBuilder: (context, error, stackTrace) {
                                // If asset image fails to load, show icon
                                return Icon(
                                  Icons.account_circle,
                                  size: 80,
                                  color: Colors.blue.shade300,
                                );
                              },
                            )
                            : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileContent(
    Map<String, dynamic> userData,
    Widget avatarWidget,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          avatarWidget,
          SizedBox(height: 20),
          Text(
            userData['name'] ?? 'Guest User',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            userData['email'] ?? 'No email provided',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),
          ElevatedButton(onPressed: () => _signOut(), child: Text('Sign Out')),
        ],
      ),
    );
  }

  void _signOut() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }
}
