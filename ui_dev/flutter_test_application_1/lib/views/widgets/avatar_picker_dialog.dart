import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AvatarPickerDialog extends StatefulWidget {
  final String? currentAvatarUrl;
  final Function(String) onAvatarSelected;

  const AvatarPickerDialog({
    Key? key,
    this.currentAvatarUrl,
    required this.onAvatarSelected,
  }) : super(key: key);

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
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

  Future<void> _uploadCustomImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
        _error = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/profile/avatar.jpg',
      );

      await storageRef.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await storageRef.getDownloadURL();
      widget.onAvatarSelected(downloadUrl);
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to upload image: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Profile Picture',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: Colors.red)),
                SizedBox(height: 16),
              ],
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  ..._presetAvatars.map(
                    (avatar) => InkWell(
                      onTap: () {
                        widget.onAvatarSelected(avatar);
                        Navigator.of(context).pop();
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: AssetImage(avatar),
                      ),
                    ),
                  ),
                  // Upload custom image option
                  InkWell(
                    onTap: _isUploading ? null : _uploadCustomImage,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      child:
                          _isUploading
                              ? CircularProgressIndicator()
                              : Icon(
                                Icons.add_photo_alternate,
                                size: 30,
                                color: Colors.grey[600],
                              ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
