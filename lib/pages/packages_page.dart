import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_service.dart';
import '../utils/travel_categories.dart';

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

  final _budgetController = TextEditingController();
  final _daysController = TextEditingController();
  int? _budget;
  int? _days;

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

  @override
  void dispose() {
    _budgetController.dispose();
    _daysController.dispose();
    super.dispose();
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
      final results = await AIService.getPersonalizedPackages(
        _preferredCategories,
        count: 6,
        budget: _budget,
        days: _days,
      );

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

    void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _applyBudget() {
    final budgetText = _budgetController.text.trim();
    final daysText = _daysController.text.trim();

    int? budget;
    if (budgetText.isNotEmpty) {
      budget = int.tryParse(budgetText);
      if (budget == null || budget < 1000) {
        _showMessage('Enter a budget of at least ₹1,000 per person.');
        return;
      }
    }

    int? days;
    if (daysText.isNotEmpty) {
      days = int.tryParse(daysText);
      if (days == null || days < 1 || days > 30) {
        _showMessage('Enter a trip length between 1 and 30 days.');
        return;
      }
    }

    setState(() {
      _budget = budget;
      _days = days;
    });
    _generatePackages();
  }

  void _clearBudget() {
    _budgetController.clear();
    _daysController.clear();
    setState(() {
      _budget = null;
      _days = null;
    });
    _generatePackages();
  }

  /// Formats a number in Indian grouping, e.g. 123456 -> ₹1,23,456
  String _inr(num value) {
    final s = value.round().toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '₹${groups.join(',')},$last3';
  }

  Map<String, int> _parseBreakdown(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, int>{};
    raw.forEach((k, v) {
      if (v is num) result[k.toString()] = v.toInt();
    });
    return result;
  }

  Widget _budgetCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.savings_outlined, color: Colors.green),
                SizedBox(width: 6),
                Text('Smart Budget',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tell us what you want to spend and AI will build packages that fit.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Budget per person',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Trip length (days)',
                      hintText: 'Any',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _applyBudget,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Find packages'),
                ),
                if (_budget != null || _days != null)
                  TextButton(
                    onPressed: _loading ? null : _clearBudget,
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownSection(Map<String, int> b) {
    final parts = [
      ('transport', 'Transport', Colors.blue),
      ('stay', 'Stay', Colors.purple),
      ('food', 'Food', Colors.orange),
      ('activities', 'Activities', Colors.green),
    ];
    final total = parts.fold<int>(0, (sum, p) => sum + (b[p.$1] ?? 0));
    if (total <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cost breakdown',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: parts
                  .where((p) => (b[p.$1] ?? 0) > 0)
                  .map((p) => Expanded(
                        flex: b[p.$1]!,
                        child: Container(height: 8, color: p.$3),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: parts
                .map((p) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text('${p.$2} ${_inr(b[p.$1] ?? 0)}',
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
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
            _budgetCard(),
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
                  final int? total = (pkg['totalPerPerson'] as num?)?.toInt();
                  final bool? withinBudget =
                      (_budget != null && total != null) ? total <= _budget! : null;
                  final breakdown = _parseBreakdown(pkg['breakdown']);
                  final String tip = (pkg['tip'] ?? '').toString();

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
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
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
                                  Text(pkg['destination'] ?? '',
                                      style: const TextStyle(color: Colors.grey)),
                                  const Spacer(),
                                  Text(
                                    pkg['budget'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green),
                                  ),
                                ],
                              ),
                              if (withinBudget != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (withinBudget ? Colors.green : Colors.red)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        withinBudget
                                            ? 'Within your budget'
                                            : '${_inr(total! - _budget!)} over budget',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: withinBudget ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
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
                              _breakdownSection(breakdown),
                              if (tip.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    '💡 $tip',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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