import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_detail_page.dart';
import 'trip_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = '';

  Future<void> _toggleLike(String tripId, List<dynamic> currentLikes, String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final safeCategory = category.isEmpty ? 'General' : category;

    if (currentLikes.contains(uid)) {
      await tripRef.update({'likes': FieldValue.arrayRemove([uid])});
      await userRef.set({
        'categoryScores': {safeCategory: FieldValue.increment(-1)}
      }, SetOptions(merge: true));
    } else {
      await tripRef.update({'likes': FieldValue.arrayUnion([uid])});
      await userRef.set({
        'categoryScores': {safeCategory: FieldValue.increment(1)}
      }, SetOptions(merge: true));
    }
  }

  Future<void> _toggleBookmark(String tripId, List<dynamic> currentBookmarks, String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final safeCategory = category.isEmpty ? 'General' : category;

    final isBookmarked = currentBookmarks.contains(uid);
    if (isBookmarked) {
      await tripRef.update({'bookmarks': FieldValue.arrayRemove([uid])});
      await userRef.set({
        'categoryScores': {safeCategory: FieldValue.increment(-2)}
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from Bucket List')),
        );
      }
    } else {
      await tripRef.update({'bookmarks': FieldValue.arrayUnion([uid])});
      await userRef.set({
        'categoryScores': {safeCategory: FieldValue.increment(2)}
      }, SetOptions(merge: true));
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('trips').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No trips available"));
                }

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
                    final tripCategory = trip['category'] ?? 'General';

                    final List<dynamic> likes = trip['likes'] ?? [];
                    final List<dynamic> bookmarks = trip['bookmarks'] ?? [];
                    final bool isLiked = likes.contains(currentUserId);
                    final bool isBookmarked = bookmarks.contains(currentUserId);

                    final List<String> tripImages = trip['images'] != null
                        ? List<String>.from(trip['images'])
                        : (trip['image'] != null && trip['image'].toString().isNotEmpty
                            ? [trip['image'].toString()]
                            : []);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailPage(tripId: tripId, tripData: trip),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            tripImages.isNotEmpty
                                ? _TripImageCarousel(images: tripImages)
                                : Container(
                                    height: 180,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 50),
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
                                  Text(
                                    "Category: $tripCategory",
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                  const Divider(),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                          color: isLiked ? Colors.red : Colors.grey,
                                        ),
                                        onPressed: () => _toggleLike(tripId, likes, tripCategory),
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
                                        onPressed: () => _toggleBookmark(tripId, bookmarks, tripCategory),
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

/// Swipeable image carousel for a trip card. Shows a single image plainly
/// if there's only one, or a swipeable PageView with dot indicators when
/// there are multiple.
class _TripImageCarousel extends StatefulWidget {
  final List<String> images;

  const _TripImageCarousel({required this.images});

  @override
  State<_TripImageCarousel> createState() => _TripImageCarouselState();
}

class _TripImageCarouselState extends State<_TripImageCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.length == 1) {
      return Image.network(
        widget.images.first,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Image.network(
                widget.images[index],
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              );
            },
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentPage
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}