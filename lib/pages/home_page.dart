import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Explore Travelink 🌍"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          TravelCard(
            image:
                "https://images.unsplash.com/photo-1507525428034-b723cf961d3e",
            title: "Maldives",
            subtitle: "Beach Paradise",
          ),
          TravelCard(
            image:
                "https://images.unsplash.com/photo-1501785888041-af3ef285b470",
            title: "Manali",
            subtitle: "Mountain Escape",
          ),
          TravelCard(
            image:
                "https://images.unsplash.com/photo-1526778548025-fa2f459cd5c1",
            title: "Paris",
            subtitle: "City of Love",
          ),
        ],
      ),
    );
  }
}

class TravelCard extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;

  const TravelCard({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Image.network(
              image,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

