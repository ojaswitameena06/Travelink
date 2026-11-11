import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/review_service.dart';
import 'add_review_page.dart';

class PlaceDetailPage extends StatelessWidget {
  final String placeId;
  final Map<String, dynamic> placeData;

  const PlaceDetailPage({super.key, required this.placeId, required this.placeData});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _fmtDate(Timestamp? ts) {
    if (ts == null) return 'Just now';
    final d = ts.toDate();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  Widget _stars(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (rating >= i + 1) {
          icon = Icons.star;
        } else if (rating >= i + 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: Colors.orange, size: size);
      }),
    );
  }

  Widget _breakdown(List<QueryDocumentSnapshot> docs) {
    final counts = List<int>.filled(5, 0);
    for (final d in docs) {
      final r = ((d.data() as Map<String, dynamic>)['rating'] as num?)?.round() ?? 0;
      if (r >= 1 && r <= 5) counts[r - 1]++;
    }
    final total = docs.length;

    return Column(
      children: [5, 4, 3, 2, 1].map((star) {
        final c = counts[star - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(width: 14, child: Text('$star', style: const TextStyle(fontSize: 12))),
              const Icon(Icons.star, size: 12, color: Colors.orange),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : c / total,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 24, child: Text('$c', style: const TextStyle(fontSize: 12))),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _openEditor(
    BuildContext context,
    String name,
    String category,
    QueryDocumentSnapshot? existing,
  ) {
    final r = existing?.data() as Map<String, dynamic>?;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddReviewPage(
          placeId: placeId,
          placeName: name,
          category: category,
          existingReviewId: existing?.id,
          existingRating: (r?['rating'] as num?)?.round(),
          existingText: r?['reviewText']?.toString(),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    QueryDocumentSnapshot doc,
    String category,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your review?'),
        content: const Text("This will also update the place's average rating."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ReviewService.deleteReview(
        reviewId: doc.id,
        placeId: placeId,
        category: category,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete the review: $e')),
        );
      }
    }
  }

  Widget _reviewCard(
    BuildContext context,
    QueryDocumentSnapshot doc,
    String? uid,
    String placeName,
    String category,
  ) {
    final r = doc.data() as Map<String, dynamic>;
    final double rating = (r['rating'] as num?)?.toDouble() ?? 0;
    final String reviewer = (r['userName'] ?? 'Traveler').toString();
    final bool isMine = uid != null && r['userId'] == uid;
    final String text = (r['reviewText'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text(
                    reviewer.isNotEmpty ? reviewer[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMine ? '$reviewer (you)' : reviewer,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          _stars(rating, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _fmtDate(r['timestamp'] as Timestamp?),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isMine)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openEditor(context, placeName, category, doc);
                      } else {
                        _confirmDelete(context, doc, category);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(text),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final db = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('places').doc(placeId).snapshots(),
      builder: (context, placeSnap) {
        final place = (placeSnap.hasData && placeSnap.data!.exists)
            ? placeSnap.data!.data() as Map<String, dynamic>
            : placeData;
        final String name = (place['name'] ?? 'Place').toString();
        final String category = (place['category'] ?? 'General').toString();
        final double? average = (place['averageRating'] as num?)?.toDouble();
        final int count = (place['reviewCount'] as num?)?.toInt() ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('reviews').where('placeId', isEqualTo: placeId).snapshots(),
          builder: (context, snapshot) {
            // Newest first; reviews still waiting for a server timestamp go on top.
            final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
            docs.sort((a, b) {
              final ta = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final tb = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              if (ta == null && tb == null) return 0;
              if (ta == null) return -1;
              if (tb == null) return 1;
              return tb.compareTo(ta);
            });

            QueryDocumentSnapshot? mine;
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              if (uid != null && data['userId'] == uid) {
                mine = d;
                break;
              }
            }

            return Scaffold(
              appBar: AppBar(title: Text(name)),
              body: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    color: Colors.blueAccent.withOpacity(0.1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📍 ${place['location'] ?? 'Unknown'}",
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 5),
                        Text("🏷️ $category",
                            style: const TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 12),
                        if (average != null && count > 0)
                          Row(
                            children: [
                              Text(
                                average.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _stars(average, size: 20),
                                  Text(
                                    '$count review${count == 1 ? '' : 's'}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          const Text('No reviews yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (docs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _breakdown(docs),
                    ),
                  const Divider(height: 24),
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('Could not load reviews: ${snapshot.error}')),
                    )
                  else if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('No reviews yet. Be the first to add one!')),
                    )
                  else
                    ...docs.map((d) => _reviewCard(context, d, uid, name, category)),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _openEditor(context, name, category, mine),
                label: Text(mine == null ? 'Add Review' : 'Edit Your Review'),
                icon: Icon(mine == null ? Icons.rate_review : Icons.edit),
              ),
            );
          },
        );
      },
    );
  }
}