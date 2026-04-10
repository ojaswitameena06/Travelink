import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_review_page.dart';

class PlaceDetailPage extends StatelessWidget {
  final String placeId;
  final Map<String, dynamic> placeData;

  const PlaceDetailPage({super.key, required this.placeId, required this.placeData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(placeData['name'] ?? 'Place Details')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: Colors.blueAccent.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("📍 ${placeData['location']}", style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 5),
                Text("🏷️ ${placeData['category']}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 24),
                    const SizedBox(width: 5),
                    Text(
                      placeData['averageRating'] != null 
                        ? "${placeData['averageRating']} (${placeData['reviewCount']} reviews)"
                        : "No reviews yet",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('placeId', isEqualTo: placeId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No reviews yet. Be the first to add one!"));

                final reviews = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Text(
                            review['rating']?.toString() ?? '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(review['reviewText'] ?? '', style: const TextStyle(fontSize: 16)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddReviewPage(placeId: placeId, placeName: placeData['name']),
              ),
            );
        },
        label: const Text("Add Review"),
        icon: const Icon(Icons.rate_review),
      ),
    );
  }
}
