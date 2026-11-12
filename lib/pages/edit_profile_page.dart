import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_upload_service.dart';
import '../services/user_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  Uint8List? _newPhotoBytes;
  String? _newPhotoName;
  String? _currentPhotoUrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final profile = await UserService.getProfile(user.uid);
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = profile.isNamed ? profile.name : (user.displayName ?? '');
      _bioCtrl.text = profile.bio;
      _currentPhotoUrl = profile.photoUrl;
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _newPhotoBytes = bytes;
      _newPhotoName = picked.name;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      _show('Please enter your name (at least 2 characters).');
      return;
    }

    setState(() => _saving = true);

    try {
      String? photoUrl;
      if (_newPhotoBytes != null) {
        final uploaded = await ImageUploadService.uploadImage(
          _newPhotoBytes!,
          _newPhotoName ?? 'avatar.jpg',
        );
        if (uploaded == null) {
          _show('Photo upload failed. Please try again.');
          return;
        }
        photoUrl = ImageUploadService.avatarUrl(uploaded);
      }

      await UserService.saveMyProfile(
        name: name,
        bio: _bioCtrl.text.trim(),
        photoUrl: photoUrl,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _show('Could not save your profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (_newPhotoBytes != null) {
      avatarImage = MemoryImage(_newPhotoBytes!);
    } else if (_currentPhotoUrl != null) {
      avatarImage = NetworkImage(_currentPhotoUrl!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? const Icon(Icons.person, size: 50, color: Colors.blueAccent)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _pickPhoto,
                            child: const CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _pickPhoto, child: const Text('Change photo')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameCtrl,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      helperText: 'Shown on your trips, reviews and chats',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bioCtrl,
                    maxLength: 150,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Tell travelers a bit about yourself',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator()
                        : const Text('Save Profile', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
    );
  }
}