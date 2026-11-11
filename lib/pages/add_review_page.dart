import 'package:flutter/material.dart';
import '../services/review_service.dart';

class AddReviewPage extends StatefulWidget {
  final String placeId;
  final String placeName;
  final String category;
  final String? existingReviewId;
  final int? existingRating;
  final String? existingText;

  const AddReviewPage({
    super.key,
    required this.placeId,
    required this.placeName,
    this.category = 'General',
    this.existingReviewId,
    this.existingRating,
    this.existingText,
  });

  @override
  State<AddReviewPage> createState() => _AddReviewPageState();
}

class _AddReviewPageState extends State<AddReviewPage> {
  final _reviewCtrl = TextEditingController();
  int _rating = 5;
  bool _isLoading = false;

  static const _labels = ['Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  bool get _isEditing => widget.existingReviewId != null;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingRating ?? 5;
    _reviewCtrl.text = widget.existingText ?? '';
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitReview() async {
    final text = _reviewCtrl.text.trim();
    if (text.isEmpty) {
      _show('Please write a review.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ReviewService.saveReview(
        placeId: widget.placeId,
        category: widget.category,
        rating: _rating,
        text: text,
        existingReviewId: widget.existingReviewId,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _show('Could not save your review: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit your review' : 'Review ${widget.placeName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How was it?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  iconSize: 40,
                  tooltip: '${i + 1} star${i == 0 ? '' : 's'}',
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                  ),
                  onPressed: () => setState(() => _rating = i + 1),
                );
              }),
            ),
            Center(
              child: Text(
                _labels[_rating - 1],
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _reviewCtrl,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Your Review',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      _isEditing ? 'Update Review' : 'Submit Review',
                      style: const TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}