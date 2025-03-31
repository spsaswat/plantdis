import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/avatar_picker_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test_application_1/utils/web_utils.dart';

/// A page that displays and manages user profile information.
///
/// This widget handles user authentication state, profile data management,
/// and avatar selection functionality.
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
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Loads user data from Firestore and handles authentication state.
  ///
  /// This method:
  /// 1. Checks for current user authentication
  /// 2. Retrieves user data from Firestore
  /// 3. Creates a new user document if one doesn't exist
  /// 4. Updates the UI state accordingly
  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userData =
            await _firestore.collection('users').doc(user.uid).get();
        if (userData.exists) {
          setState(() {
            _userName = userData.data()?['name'] ?? 'User';
            _userEmail = user.email;
            _avatarUrl =
                userData.data()?['avatarUrl'] ?? 'assets/avatars/botanist.png';
            _isLoading = false;
          });
        } else {
          await _createNewUserDocument(user);
        }
      } else {
        setState(() {
          _errorMessage = 'No user logged in';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading user data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Creates a new user document in Firestore with default values.
  Future<void> _createNewUserDocument(User user) async {
    try {
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating user document: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Updates the user's avatar URL in Firestore and local state.
  Future<void> _updateAvatar(String newAvatarUrl) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'avatarUrl': newAvatarUrl,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _avatarUrl = newAvatarUrl;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating avatar: ${e.toString()}')),
        );
      }
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
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
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _userName ?? 'Loading...',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _userEmail ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
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
            const Text(
              'Avatar Credits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Special thanks to the following artists for their beautiful avatars:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  credit,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
