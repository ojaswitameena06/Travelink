import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_detail_page.dart';

class TripDetailPage extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> tripData;

  const TripDetailPage({super.key, required this.tripId, required this.tripData});

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(List<dynamic> currentLikes, String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(widget.tripId);
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

  Future<void> _toggleBookmark(List<dynamic> currentBookmarks, String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(widget.tripId);
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

  void _startChatWithTraveler(Map<String, dynamic> trip) {
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('trips').doc(widget.tripId).snapshots(),
        builder: (context, snapshot) {
          final trip = snapshot.hasData && snapshot.data!.exists
              ? snapshot.data!.data() as Map<String, dynamic>
              : widget.tripData;

          final List<dynamic> likes = trip['likes'] ?? [];
          final List<dynamic> bookmarks = trip['bookmarks'] ?? [];
          final bool isLiked = likes.contains(currentUserId);
          final bool isBookmarked = bookmarks.contains(currentUserId);
          final String category = trip['category'] ?? 'General';

          final List<String> images = trip['images'] != null
              ? List<String>.from(trip['images'])
              : (trip['image'] != null && trip['image'].toString().isNotEmpty
                  ? [trip['image'].toString()]
                  : []);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 320,
                flexibleSpace: FlexibleSpaceBar(
                  background: images.isEmpty
                      ? Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 60),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: images.length,
                              onPageChanged: (i) => setState(() => _currentPage = i),
                              itemBuilder: (context, i) {
                                return Image.network(images[i], fit: BoxFit.cover);
                              },
                            ),
                            if (images.length > 1)
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(images.length, (i) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: i == _currentPage
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.4),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip['title'] ?? 'No title',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(category),
                        backgroundColor: Colors.blueAccent.withOpacity(0.15),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        trip['description'] ?? '',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.grey,
                            ),
                            onPressed: () => _toggleLike(likes, category),
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
                            onPressed: () => _toggleBookmark(bookmarks, category),
                            tooltip: isBookmarked ? 'Remove Bookmark' : 'Add to Bucket List',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text("Ask Traveler About This Trip"),
                          onPressed: () => _startChatWithTraveler(trip),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}