import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AvatarPickerDialog extends StatefulWidget {
  final String? currentAvatarUrl;
  final Function(String) onAvatarSelected;

  const AvatarPickerDialog({
    super.key,
    this.currentAvatarUrl,
    required this.onAvatarSelected,
  });

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
  bool _isUploading = false;
  String? _error;

  // Predefined avatars based on personas
  final List<String> _presetAvatars = [
    'assets/avatars/forest ranger.png',
    'assets/avatars/farmer.png',
    'assets/avatars/gardener.png',
    'assets/avatars/botanist.png',
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

      // get bytes
      final bytes = await image.readAsBytes();

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/profile/avatar.jpg');

      //  Upload byte instead of file
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get download URL and return
      final downloadUrl = await storageRef.getDownloadURL();
      if (mounted) {
        widget.onAvatarSelected(downloadUrl);
        Navigator.of(context).pop();
      }
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
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
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
                              ? const CircularProgressIndicator()
                              : Icon(
                                Icons.add_photo_alternate,
                                size: 30,
                                color: Colors.grey[600],
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
