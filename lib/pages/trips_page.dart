import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_trip_page.dart';
import 'trip_detail_page.dart';

class TripsPage extends StatelessWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("My Trips ✈️")),
      body: userId == null
          ? const Center(child: Text("Please log in to see your trips."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('trips')
                  .where('userId', isEqualTo: userId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error loading trips: ${snapshot.error}'),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("You haven't added any trips yet."));
                }

                final trips = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final tripDoc = trips[index];
                    final trip = tripDoc.data() as Map<String, dynamic>;
                    final tripId = tripDoc.id;

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
                            if (tripImages.isNotEmpty)
                              _TripThumbnailCarousel(images: tripImages)
                            else
                              Container(
                                height: 150,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image, size: 40),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTripPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Swipeable thumbnail carousel for a trip card on the "My Trips" list.
class _TripThumbnailCarousel extends StatefulWidget {
  final List<String> images;

  const _TripThumbnailCarousel({required this.images});

  @override
  State<_TripThumbnailCarousel> createState() => _TripThumbnailCarouselState();
}

class _TripThumbnailCarouselState extends State<_TripThumbnailCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.length == 1) {
      return Image.network(
        widget.images.first,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Image.network(
                widget.images[index],
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              );
            },
          ),
          Positioned(
            bottom: 6,
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