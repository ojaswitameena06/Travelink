import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_upload_service.dart';
import '../utils/travel_categories.dart';

class EditTripPage extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> tripData;

  const EditTripPage({super.key, required this.tripId, required this.tripData});

  @override
  State<EditTripPage> createState() => _EditTripPageState();
}

class _EditTripPageState extends State<EditTripPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  late List<String> _existingUrls;
  final List<Uint8List> _newBytes = [];
  final List<String> _newNames = [];
  bool _saving = false;

  static const int _maxImages = 10;

  int get _totalImages => _existingUrls.length + _newBytes.length;

  // Keeps an older/unknown category selectable instead of silently changing it.
  List<String> get _categoryOptions =>
      kTravelCategories.contains(_category) ? kTravelCategories : [_category, ...kTravelCategories];

  @override
  void initState() {
    super.initState();
    final t = widget.tripData;
    _titleCtrl = TextEditingController(text: (t['title'] ?? '').toString());
    _descCtrl = TextEditingController(text: (t['description'] ?? '').toString());

    final cat = (t['category'] ?? '').toString();
    _category = cat.isNotEmpty ? cat : kTravelCategories.first;

    _existingUrls = t['images'] != null
        ? List<String>.from(t['images'])
        : (t['image'] != null && t['image'].toString().isNotEmpty
            ? [t['image'].toString()]
            : <String>[]);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _totalImages;
    if (remaining <= 0) {
      _show('Maximum $_maxImages photos per trip');
      return;
    }

    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    final toAdd = picked.length > remaining ? picked.sublist(0, remaining) : picked;
    if (picked.length > remaining) {
      _show('Only added ${toAdd.length} - max $_maxImages photos per trip');
    }

    for (final file in toAdd) {
      _newBytes.add(await file.readAsBytes());
      _newNames.add(file.name);
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _show('Please add a title.');
      return;
    }
    if (_totalImages == 0) {
      _show('Keep at least one photo.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.tripData['userId'] != user.uid) {
      _show('You can only edit your own trips.');
      return;
    }

    setState(() => _saving = true);

    try {
      final urls = List<String>.from(_existingUrls);
      for (var i = 0; i < _newBytes.length; i++) {
        final url = await ImageUploadService.uploadImage(_newBytes[i], _newNames[i]);
        if (url == null) {
          _show('One or more photos failed to upload. Please try again.');
          return;
        }
        urls.add(url);
      }

      await FirebaseFirestore.instance.collection('trips').doc(widget.tripId).update({
        'title': title,
        'description': _descCtrl.text.trim(),
        'category': _category,
        'images': urls,
        'image': urls.first,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _show('Could not save changes: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _thumb(Widget image, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 110, height: 110, child: image),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                padding: const EdgeInsets.all(3),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Trip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Trip Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Trip Category',
                border: OutlineInputBorder(),
              ),
              items: _categoryOptions
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Photos ($_totalImages/$_maxImages)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _existingUrls.length; i++)
                    _thumb(
                      Image.network(_existingUrls[i], fit: BoxFit.cover),
                      () => setState(() => _existingUrls.removeAt(i)),
                    ),
                  for (var i = 0; i < _newBytes.length; i++)
                    _thumb(
                      Image.memory(_newBytes[i], fit: BoxFit.cover),
                      () => setState(() {
                        _newBytes.removeAt(i);
                        _newNames.removeAt(i);
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _totalImages >= _maxImages ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add Photos'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Save Changes', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}