import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = '';

  Future<void> _toggleLike(String tripId, List<dynamic> currentLikes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final uid = user.uid;
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);

    if (currentLikes.contains(uid)) {
      await tripRef.update({
        'likes': FieldValue.arrayRemove([uid])
      });
    } else {
      await tripRef.update({
        'likes': FieldValue.arrayUnion([uid])
      });
    }
  }

  Future<void> _toggleBookmark(String tripId, List<dynamic> currentBookmarks) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);

    final isBookmarked = currentBookmarks.contains(uid);
    if (isBookmarked) {
      await tripRef.update({
        'bookmarks': FieldValue.arrayRemove([uid])
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from Bucket List')),
        );
      }
    } else {
      await tripRef.update({
        'bookmarks': FieldValue.arrayUnion([uid])
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Bucket List 🎯')),
        );
      }
    }
  }

  void _startChatWithTraveler(BuildContext context, Map<String, dynamic> trip) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to chat with travelers.')),
      );
      return;
    }

    final authorUid = trip['userId'] ?? '';
    final destination = trip['title'] ?? 'Trip';

    if (authorUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Author information unavailable.')),
      );
      return;
    }

    if (authorUid == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your own trip post!')),
      );
      return;
    }

    // Generate deterministic chatId
    final ids = [currentUser.uid, authorUid]..sort();
    final chatId = ids.join('_');
    final recipientName = "Traveler ${authorUid.substring(0, 4)}";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          chatId: chatId,
          recipientUid: authorUid,
          recipientName: recipientName,
          destination: destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Explore Travelink 🌍"),
      ),

      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search trips by title or description...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase().trim();
                });
              },
            ),
          ),

          // 📜 Trips Feed
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('trips').snapshots(),
              builder: (context, snapshot) {

                // 🔄 Loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // ❌ No data
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No trips available"));
                }

                // Filter trips by search query
                final allTrips = snapshot.data!.docs;
                final filteredTrips = allTrips.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final desc = (data['description'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery) || desc.contains(_searchQuery);
                }).toList();

                if (filteredTrips.isEmpty) {
                  return const Center(child: Text("No matching trips found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTrips.length,
                  itemBuilder: (context, index) {
                    final tripDoc = filteredTrips[index];
                    final trip = tripDoc.data() as Map<String, dynamic>;
                    final tripId = tripDoc.id;

                    final List<dynamic> likes = trip['likes'] ?? [];
                    final List<dynamic> bookmarks = trip['bookmarks'] ?? [];
                    final bool isLiked = likes.contains(currentUserId);
                    final bool isBookmarked = bookmarks.contains(currentUserId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15)),
                            child: (trip['image'] != null &&
                                    trip['image'].toString().isNotEmpty)
                                ? Image.network(
                                    trip['image'],
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 180,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 50),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip['title'] ?? 'No title',
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 5),
                                Text(trip['description'] ?? ''),
                                const Divider(),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        color: isLiked ? Colors.red : Colors.grey,
                                      ),
                                      onPressed: () => _toggleLike(tripId, likes),
                                    ),
                                    Text(
                                      "${likes.length} Likes",
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: Icon(
                                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                        color: isBookmarked ? Colors.amber[800] : Colors.grey,
                                      ),
                                      onPressed: () => _toggleBookmark(tripId, bookmarks),
                                      tooltip: isBookmarked ? 'Remove Bookmark' : 'Add to Bucket List',
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                      label: const Text("Ask Traveler"),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () => _startChatWithTraveler(context, trip),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
