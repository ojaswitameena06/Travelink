import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/travel_categories.dart';

class AddBuddyPlanPage extends StatefulWidget {
  const AddBuddyPlanPage({super.key});

  @override
  State<AddBuddyPlanPage> createState() => _AddBuddyPlanPageState();
}

class _AddBuddyPlanPageState extends State<AddBuddyPlanPage> {
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController();
  final _noteController = TextEditingController();
  DateTimeRange? _dates;
  final Set<String> _interests = {};
  int _buddiesWanted = 1;
  bool _saving = false;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  void dispose() {
    _destinationController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      initialDateRange: _dates,
    );
    if (picked != null) {
      setState(() => _dates = picked);
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _show('Please log in first.');
      return;
    }

    final destination = _destinationController.text.trim();
    if (destination.isEmpty || _dates == null || _interests.isEmpty) {
      _show('Add a destination, travel dates and at least one interest.');
      return;
    }

    setState(() => _saving = true);

    try {
      final name = (user.displayName ?? '').trim();
      await FirebaseFirestore.instance.collection('buddy_plans').add({
        'userId': user.uid,
        'displayName': name.isNotEmpty ? name : 'Traveler ${user.uid.substring(0, 4)}',
        'destination': destination,
        'startDate': Timestamp.fromDate(_dates!.start),
        'endDate': Timestamp.fromDate(_dates!.end),
        'budget': int.tryParse(_budgetController.text.trim()) ?? 0,
        'categories': _interests.toList(),
        'buddiesWanted': _buddiesWanted,
        'note': _noteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _show('Could not save your plan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post My Travel Plan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Where are you going?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _dates == null
                    ? 'Select travel dates'
                    : '${_fmt(_dates!.start)} – ${_fmt(_dates!.end)}',
              ),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Budget per person',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Your travel interests', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: kTravelCategories.map((cat) {
                return FilterChip(
                  label: Text(cat),
                  selected: _interests.contains(cat),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _interests.add(cat);
                      } else {
                        _interests.remove(cat);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              value: _buddiesWanted,
              decoration: const InputDecoration(
                labelText: 'How many buddies are you looking for?',
                border: OutlineInputBorder(),
              ),
              items: [1, 2, 3, 4, 5]
                  .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _buddiesWanted = val);
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'A short note (travel style, plans...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Post Plan', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}