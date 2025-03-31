import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class AvatarPickerDialog extends StatefulWidget {
  final String? currentAvatarUrl;
  final Function(String) onAvatarSelected;

  const AvatarPickerDialog({
    Key? key,
    this.currentAvatarUrl,
    required this.onAvatarSelected,
  }) : super(key: key);

  @override
  _AvatarPickerDialogState createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _error;

  // Predefined avatars based on personas
  final List<String> _presetAvatars = [
    'assets/avatars/farmer.png', // Farmer persona
    'assets/avatars/researcher.png', // Researcher persona
    'assets/avatars/student.png', // Student persona
    'assets/avatars/hobbyist.png', // Garden hobbyist persona
    'assets/avatars/professional.png', // Agriculture professional
  ];

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> _uploadCustomAvatar(File imageFile) async {
    try {
      setState(() {
        _isUploading = true;
        _error = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'avatar_$timestamp.jpg';

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/profile/$filename',
      );

      await storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update the avatar
      widget.onAvatarSelected(downloadUrl);

      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to upload image: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _pickCustomAvatar(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final hasPermission = await _requestCameraPermission();
        if (!hasPermission) {
          setState(() {
            _error = 'Camera permission is required to take photos';
          });
          return;
        }
      }

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _uploadCustomAvatar(File(pickedFile.path));
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  void _showCustomPickerOptions() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select Image Source'),
            content: Text('Choose the image source for your custom avatar.'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Close source selection dialog
                  await _pickCustomAvatar(ImageSource.camera);
                },
                child: Text('Camera'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Close source selection dialog
                  await _pickCustomAvatar(ImageSource.gallery);
                },
                child: Text('Gallery'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Choose Your Avatar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(_error!, style: TextStyle(color: Colors.red)),
              ),
            _buildAvatarOption(
              context,
              'Botanist',
              'assets/avatars/botanist.png',
              'A professional plant scientist',
            ),
            _buildAvatarOption(
              context,
              'Farmer',
              'assets/avatars/farmer.png',
              'A friendly farmer',
            ),
            _buildAvatarOption(
              context,
              'Gardener',
              'assets/avatars/gardener.png',
              'A dedicated gardener',
            ),
            _buildAvatarOption(
              context,
              'Plant Character',
              'assets/avatars/plant.png',
              'A cute plant character',
            ),
            _buildAvatarOption(
              context,
              'Forest Ranger',
              'assets/avatars/forest ranger.png',
              'A nature expert',
            ),
            SizedBox(height: 16),
            _buildCustomAvatarOption(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildAvatarOption(
    BuildContext context,
    String title,
    String imagePath,
    String description,
  ) {
    final isSelected = widget.currentAvatarUrl == imagePath;

    return InkWell(
      onTap: () {
        widget.onAvatarSelected(imagePath);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Image.asset(imagePath, width: 50, height: 50),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAvatarOption(BuildContext context) {
    return InkWell(
      onTap: _isUploading ? null : _showCustomPickerOptions,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (_isUploading)
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(),
              )
            else
              Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Avatar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _isUploading
                        ? 'Uploading...'
                        : 'Choose from gallery or take a new picture',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
