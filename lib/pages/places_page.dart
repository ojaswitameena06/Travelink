import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/travel_categories.dart';
import 'place_detail_page.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  String _selectedCategory = 'All';

  Future<void> _openInMaps(String name, String location) async {
    final query = Uri.encodeComponent('$name, $location');
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open Google Maps")),
        );
      }
    }
  }

  Future<void> _togglePlaceBookmark(
    String placeId,
    String category,
    List<dynamic> currentBookmarks,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save places.')),
        );
      }
      return;
    }

    final uid = user.uid;
    final placeRef = FirebaseFirestore.instance.collection('places').doc(placeId);
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final safeCategory = category.isEmpty ? 'General' : category;

    final isBookmarked = currentBookmarks.contains(uid);

    if (isBookmarked) {
      await placeRef.update({'bookmarks': FieldValue.arrayRemove([uid])});
      await userRef.set({
        'categoryScores': {safeCategory: FieldValue.increment(-1)}
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from saved places')),
        );
      }
    } else {
      await placeRef.update({'bookmarks': FieldValue.arrayUnion([uid])});
      await userRef.set({
        'categoryScores': {safeCategory: FieldValue.increment(1)}
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved! We\'ll use this to personalize your packages 🎯')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final filterChips = ['All', ...kTravelCategories];

    return Scaffold(
      appBar: AppBar(title: const Text("Places & Reviews 🏢")),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: filterChips.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: Colors.blueAccent.withOpacity(0.2),
                    checkmarkColor: Colors.blueAccent,
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('places').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No places added yet. Be the first!"));
                }

                final allPlaces = snapshot.data!.docs;
                final filteredPlaces = allPlaces.where((doc) {
                  if (_selectedCategory == 'All') return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final cat = (data['category'] ?? '').toString();
                  return cat.toLowerCase() == _selectedCategory.toLowerCase();
                }).toList();

                if (filteredPlaces.isEmpty) {
                  return Center(
                    child: Text("No places found for category '$_selectedCategory'"),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPlaces.length,
                  itemBuilder: (context, index) {
                    final place = filteredPlaces[index].data() as Map<String, dynamic>;
                    final placeId = filteredPlaces[index].id;
                    final placeName = place['name'] ?? 'Unnamed Place';
                    final placeLocation = place['location'] ?? '';
                    final placeCategory = place['category'] ?? 'General';
                    final List<dynamic> bookmarks = place['bookmarks'] ?? [];
                    final isBookmarked = bookmarks.contains(currentUserId);

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          child: const Icon(Icons.place, color: Colors.blueAccent),
                        ),
                        title: Text(
                          placeName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text("Category: $placeCategory"),
                            Text("Location: ${placeLocation.isEmpty ? 'Unknown' : placeLocation}"),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.orange, size: 18),
                                const SizedBox(width: 5),
                                Text(
                                  place['averageRating'] != null
                                      ? place['averageRating'].toString()
                                      : "No ratings",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                color: isBookmarked ? Colors.amber[800] : Colors.grey,
                              ),
                              tooltip: isBookmarked ? "Remove bookmark" : "Save this place",
                              onPressed: () =>
                                  _togglePlaceBookmark(placeId, placeCategory, bookmarks),
                            ),
                            IconButton(
                              icon: const Icon(Icons.map_outlined, color: Colors.blueAccent),
                              tooltip: "Open in Google Maps",
                              onPressed: () => _openInMaps(placeName, placeLocation),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlaceDetailPage(placeId: placeId, placeData: place),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPlaceDialog(context),
        child: const Icon(Icons.add_location_alt),
      ),
    );
  }

  void _showAddPlaceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String categoryValue = kTravelCategories.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Place"),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Place Name"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: categoryValue,
                    decoration: const InputDecoration(labelText: "Category"),
                    items: kTravelCategories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          categoryValue = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: "City / Location"),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                FirebaseFirestore.instance.collection('places').add({
                  'name': nameCtrl.text,
                  'category': categoryValue,
                  'location': locationCtrl.text,
                  'averageRating': null,
                  'reviewCount': 0,
                  'bookmarks': [],
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
}