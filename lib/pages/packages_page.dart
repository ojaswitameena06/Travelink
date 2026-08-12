import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ai_chatbot_page.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key});

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  String _selectedCategory = 'All';

  final List<Map<String, dynamic>> _samplePackages = [
    {
      'id': 'pkg1',
      'title': 'Kerala Backwaters & Tea Garden Escape',
      'destination': 'Kerala',
      'category': 'Nature',
      'duration': '5 Days / 4 Nights',
      'budget': '₹24,999 / person',
      'image': 'https://picsum.photos/id/1015/600/400',
      'highlights': ['Houseboat Cruise', 'Munnar Tea Estates', 'Spice Plantation'],
      'isRecommended': true,
    },
    {
      'id': 'pkg2',
      'title': 'Goa Sun, Sand & Heritage Package',
      'destination': 'Goa',
      'category': 'Beach',
      'duration': '4 Days / 3 Nights',
      'budget': '₹18,500 / person',
      'image': 'https://picsum.photos/id/1039/600/400',
      'highlights': ['North Goa Beaches', 'Old Goa Churches', 'Sunset Mandovi Cruise'],
      'isRecommended': true,
    },
    {
      'id': 'pkg3',
      'title': 'Royal Rajasthan Palaces & Forts Tour',
      'destination': 'Jaipur & Udaipur',
      'category': 'Heritage',
      'duration': '6 Days / 5 Nights',
      'budget': '₹32,000 / person',
      'image': 'https://picsum.photos/id/1043/600/400',
      'highlights': ['Amber Fort Safari', 'Lake Pichola Boating', 'Desert Camping'],
      'isRecommended': false,
    },
    {
      'id': 'pkg4',
      'title': 'Manali & Solang Valley Snow Adventure',
      'destination': 'Manali',
      'category': 'Adventure',
      'duration': '5 Days / 4 Nights',
      'budget': '₹21,000 / person',
      'image': 'https://picsum.photos/id/1036/600/400',
      'highlights': ['Solang Paragliding', 'Atal Tunnel Visit', 'River Rafting'],
      'isRecommended': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _samplePackages.where((pkg) {
      if (_selectedCategory == 'All') return true;
      return pkg['category'] == _selectedCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Travel Packages & AI Suggestions 🎁"),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🤖 AI Assistant Banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blueAccent, Colors.indigoAccent],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Need a Customized Plan?",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Ask Travelink AI to build a custom travel package tailored for your exact budget!",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blueAccent,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AIChatbotPage()),
                      );
                    },
                    child: const Text("Ask AI"),
                  ),
                ],
              ),
            ),

            // 🎯 Recommended For You Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                children: [
                  Icon(Icons.stars, color: Colors.orange),
                  SizedBox(width: 6),
                  Text(
                    "Recommended For You (AI Personalization)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // 🏷️ Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: ['All', 'Beach', 'Nature', 'Heritage', 'Adventure'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: Colors.blueAccent.withOpacity(0.2),
                      checkmarkColor: Colors.blueAccent,
                      onSelected: (val) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // 📦 Packages Feed
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final pkg = filtered[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.network(
                              pkg['image'],
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (pkg['isRecommended'] == true)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber[800],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      "Top AI Pick",
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                pkg['duration'],
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pkg['title'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                                const SizedBox(width: 4),
                                Text(pkg['destination'], style: const TextStyle(color: Colors.grey)),
                                const Spacer(),
                                Text(
                                  pkg['budget'],
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Wrap(
                              spacing: 6,
                              children: (pkg['highlights'] as List<String>).map((h) {
                                return Chip(
                                  label: Text(h, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.grey[200],
                                  padding: EdgeInsets.zero,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.chat_outlined, size: 18),
                                label: const Text("Ask AI Assistant About This Package"),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AIChatbotPage()),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
