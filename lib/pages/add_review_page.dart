import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddReviewPage extends StatefulWidget {
  final String placeId;
  final String placeName;

  const AddReviewPage({super.key, required this.placeId, required this.placeName});

  @override
  State<AddReviewPage> createState() => _AddReviewPageState();
}

class _AddReviewPageState extends State<AddReviewPage> {
  final _reviewCtrl = TextEditingController();
  double _rating = 5.0;
  bool _isLoading = false;

  Future<void> _submitReview() async {
    if (_reviewCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a review.')));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance.collection('reviews').add({
        'placeId': widget.placeId,
        'userId': user?.uid ?? 'anonymous',
        'rating': _rating,
        'reviewText': _reviewCtrl.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update place average rating simply
      final placeDoc = await FirebaseFirestore.instance.collection('places').doc(widget.placeId).get();
      if (placeDoc.exists) {
        final data = placeDoc.data()!;
        final currentCount = (data['reviewCount'] ?? 0) as int;
        final currentAvg = (data['averageRating'] ?? 0.0) as num;
        
        final newCount = currentCount + 1;
        final newAvg = ((currentAvg * currentCount) + _rating) / newCount;
        
        await FirebaseFirestore.instance.collection('places').doc(widget.placeId).update({
          'reviewCount': newCount,
          'averageRating': double.parse(newAvg.toStringAsFixed(1)),
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Review ${widget.placeName}")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Rating out of 5:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(
                value: _rating,
                min: 1,
                max: 5,
                divisions: 4,
                label: _rating.toString(),
                onChanged: (val) {
                  setState(() => _rating = val);
                },
              ),
              Center(child: Text("⭐ $_rating", style: const TextStyle(fontSize: 24))),
              const SizedBox(height: 20),
              TextField(
                controller: _reviewCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Your Review',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text("Submit Review", style: TextStyle(fontSize: 18)),
              )
            ],
          ),
        ),
    );
  }
}
