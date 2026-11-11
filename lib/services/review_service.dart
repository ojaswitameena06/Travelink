import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  static String displayNameFor(User user) {
    final name = (user.displayName ?? '').trim();
    return name.isNotEmpty ? name : 'Traveler ${user.uid.substring(0, 4)}';
  }

  /// Creates a review, or updates the user's existing one, and keeps the
  /// place's rating aggregate (reviewCount, ratingSum, averageRating) in sync
  /// inside a single transaction.
  static Future<void> saveReview({
    required String placeId,
    required String category,
    required int rating,
    required String text,
    String? existingReviewId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please log in to write a review.');
    }

    final db = FirebaseFirestore.instance;
    final placeRef = db.collection('places').doc(placeId);
    final reviewRef =
        db.collection('reviews').doc(existingReviewId ?? '${placeId}_${user.uid}');
    final userRef = db.collection('users').doc(user.uid);
    final safeCategory = category.isEmpty ? 'General' : category;

    await db.runTransaction((tx) async {
      final placeSnap = await tx.get(placeRef);
      final reviewSnap = await tx.get(reviewRef);

      final placeData = placeSnap.data() ?? <String, dynamic>{};
      var count = (placeData['reviewCount'] as num?)?.toInt() ?? 0;
      var sum = (placeData['ratingSum'] as num?)?.toDouble() ??
          ((placeData['averageRating'] as num?)?.toDouble() ?? 0) * count;

      double? oldRating;
      if (reviewSnap.exists) {
        final existing = reviewSnap.data();
        if (existing != null && existing['userId'] != user.uid) {
          throw Exception('You can only edit your own review.');
        }
        oldRating = (existing?['rating'] as num?)?.toDouble();
      }

      if (oldRating != null) {
        sum = sum - oldRating + rating;
      } else {
        sum += rating;
        count += 1;
      }
      final average = count == 0 ? 0.0 : sum / count;

      tx.set(reviewRef, {
        'placeId': placeId,
        'userId': user.uid,
        'userName': displayNameFor(user),
        'rating': rating,
        'reviewText': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (placeSnap.exists) {
        tx.update(placeRef, {
          'reviewCount': count,
          'ratingSum': sum,
          'averageRating': double.parse(average.toStringAsFixed(1)),
        });
      }

      // A 4+ star review counts as a positive signal for personalization.
      final delta = (rating >= 4 ? 1 : 0) - ((oldRating ?? 0) >= 4 ? 1 : 0);
      if (delta != 0) {
        tx.set(
          userRef,
          {
            'categoryScores': {safeCategory: FieldValue.increment(delta)}
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  static Future<void> deleteReview({
    required String reviewId,
    required String placeId,
    required String category,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please log in first.');
    }

    final db = FirebaseFirestore.instance;
    final reviewRef = db.collection('reviews').doc(reviewId);
    final placeRef = db.collection('places').doc(placeId);
    final userRef = db.collection('users').doc(user.uid);
    final safeCategory = category.isEmpty ? 'General' : category;

    await db.runTransaction((tx) async {
      final reviewSnap = await tx.get(reviewRef);
      if (!reviewSnap.exists) return;
      final placeSnap = await tx.get(placeRef);

      final review = reviewSnap.data()!;
      if (review['userId'] != user.uid) {
        throw Exception('You can only delete your own review.');
      }
      final rating = (review['rating'] as num?)?.toDouble() ?? 0;

      final placeData = placeSnap.data() ?? <String, dynamic>{};
      var count = (placeData['reviewCount'] as num?)?.toInt() ?? 0;
      var sum = (placeData['ratingSum'] as num?)?.toDouble() ??
          ((placeData['averageRating'] as num?)?.toDouble() ?? 0) * count;

      count = count > 0 ? count - 1 : 0;
      sum = sum - rating;
      if (sum < 0 || count == 0) sum = 0;

      tx.delete(reviewRef);

      if (placeSnap.exists) {
        tx.update(placeRef, {
          'reviewCount': count,
          'ratingSum': sum,
          // Removing the field makes the Places list show "No ratings" again.
          'averageRating': count == 0
              ? FieldValue.delete()
              : double.parse((sum / count).toStringAsFixed(1)),
        });
      }

      if (rating >= 4) {
        tx.set(
          userRef,
          {
            'categoryScores': {safeCategory: FieldValue.increment(-1)}
          },
          SetOptions(merge: true),
        );
      }
    });
  }
}