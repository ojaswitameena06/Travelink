import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../utils/travel_categories.dart';

class AddTripPage extends StatefulWidget {
  const AddTripPage({super.key});

  @override
  State<AddTripPage> createState() => _AddTripPageState();
}

class _AddTripPageState extends State<AddTripPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;
  String _selectedCategory = kTravelCategories.first;

  static const int _maxImages = 10;
  final List<Uint8List> _pickedImageBytes = [];
  final List<String> _pickedFileNames = [];

  static const String _cloudName = 'xchdbm68';
  static const String _uploadPreset = 'travelink_trips';

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 85);

    if (picked.isEmpty) return;

    final remainingSlots = _maxImages - _pickedImageBytes.length;
    if (remainingSlots <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum $_maxImages photos allowed')),
        );
      }
      return;
    }

    final toAdd = picked.length > remainingSlots ? picked.sublist(0, remainingSlots) : picked;
    if (picked.length > remainingSlots && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only added ${toAdd.length} — max $_maxImages photos per trip')),
      );
    }

    for (final file in toAdd) {
      final bytes = await file.readAsBytes();
      _pickedImageBytes.add(bytes);
      _pickedFileNames.add(file.name);
    }

    setState(() {});
  }

  void _removeImage(int index) {
    setState(() {
      _pickedImageBytes.removeAt(index);
      _pickedFileNames.removeAt(index);
    });
  }

  Future<String?> _uploadOneToCloudinary(Uint8List bytes, String fileName) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final response = await request.send();
    final resBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(resBody);
      return data['secure_url'] as String?;
    }
    return null;
  }

  Future<void> _saveTrip() async {
    if (_titleController.text.isEmpty || _pickedImageBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title and at least one photo')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final List<String> imageUrls = [];
      for (var i = 0; i < _pickedImageBytes.length; i++) {
        final url = await _uploadOneToCloudinary(_pickedImageBytes[i], _pickedFileNames[i]);
        if (url == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('One or more photos failed to upload. Please try again.')),
            );
          }
          setState(() { _isLoading = false; });
          return;
        }
        imageUrls.add(url);
      }

      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';

      await FirebaseFirestore.instance.collection('trips').add({
        'title': _titleController.text,
        'description': _descController.text,
        'images': imageUrls,
        'image': imageUrls.first, // kept for backward compatibility with older code paths
        'category': _selectedCategory,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Trip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Trip Details",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Trip Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Trip Category',
                border: OutlineInputBorder(),
              ),
              items: kTravelCategories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: 20),

            Text(
              "Photos (${_pickedImageBytes.length}/$_maxImages)",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_pickedImageBytes.isNotEmpty)
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pickedImageBytes.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _pickedImageBytes[index],
                              height: 110,
                              width: 110,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(3),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 40, color: Colors.grey),
                ),
              ),

            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickedImageBytes.length >= _maxImages ? null : _pickImages,
              icon: const Icon(Icons.upload),
              label: Text(_pickedImageBytes.isEmpty ? 'Upload Photos' : 'Add More Photos'),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveTrip,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Save Trip', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}