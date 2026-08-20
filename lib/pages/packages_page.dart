import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_service.dart';
import '../utils/travel_categories.dart';
import 'ai_chatbot_page.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key});

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  String _selectedCategory = 'All';
  String? _topCategory;
  List<String> _preferredCategories = [];
  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;
  String? _error;

  final List<String> _placeholderImages = [
    'https://picsum.photos/id/1015/600/400',
    'https://picsum.photos/id/1039/600/400',
    'https://picsum.photos/id/1043/600/400',
    'https://picsum.photos/id/1036/600/400',
    'https://picsum.photos/id/1025/600/400',
    'https://picsum.photos/id/1011/600/400',
    'https://picsum.photos/id/1018/600/400',
    'https://picsum.photos/id/1048/600/400',
    'https://picsum.photos/id/1050/600/400',
    'https://picsum.photos/id/1062/600/400',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadPreferredCategories();
    await _generatePackages();
  }

  Future<void> _loadPreferredCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final scores = (doc.data()?['categoryScores'] as Map<String, dynamic>?) ?? {};

    final entries = scores.entries
        .where((e) => (e.value as num?) != null && (e.value as num) > 0)
        .toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    if (mounted) {
      setState(() {
        _preferredCategories = entries.take(3).map((e) => e.key).toList();
        _topCategory = _preferredCategories.isNotEmpty ? _preferredCategories.first : null;
      });
    }
  }

  Future<void> _generatePackages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await AIService.getPersonalizedPackages(_preferredCategories, count: 6);

      for (var i = 0; i < results.length; i++) {
        results[i]['image'] = _placeholderImages[i % _placeholderImages.length];
      }

      if (mounted) {
        setState(() {
          _packages = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Couldn't generate packages right now. Please try again.";
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _packages.where((pkg) {
      if (_selectedCategory == 'All') return true;
      return pkg['category'] == _selectedCategory;
    }).toList();

    if (_topCategory != null) {
      filtered.sort((a, b) {
        final aMatch = a['category'] == _topCategory ? 1 : 0;
        final bMatch = b['category'] == _topCategory ? 1 : 0;
        return bMatch.compareTo(aMatch);
      });
    }

    final filterChips = ['All', ...kTravelCategories];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Travel Packages & AI Suggestions 🎁"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Generate fresh recommendations",
            onPressed: _loading ? null : _generatePackages,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _topCategory != null
                          ? "Recommended For You — you love $_topCategory trips 🎯"
                          : "Recommended For You (AI Personalization)",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            if (!_loading && _topCategory == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Like or bookmark trips and places you enjoy to get personalized picks here!",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
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
                      onSelected: (val) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text("AI is curating packages for you..."),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _generatePackages,
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text("No packages found for this category.")),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final pkg = filtered[index];
                  final bool isTopPick = _topCategory != null && pkg['category'] == _topCategory;
                  final highlights = (pkg['highlights'] as List?)?.cast<String>() ?? [];

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
                                pkg['image'] ?? _placeholderImages[0],
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (isTopPick)
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
                                  pkg['duration'] ?? '',
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
                                pkg['title'] ?? 'Untitled Package',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                                  const SizedBox(width: 4),
                                  Text(pkg['destination'] ?? '', style: const TextStyle(color: Colors.grey)),
                                  const Spacer(),
                                  Text(
                                    pkg['budget'] ?? '',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Wrap(
                                spacing: 6,
                                children: highlights.map((h) {
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