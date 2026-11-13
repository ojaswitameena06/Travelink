import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripActions {
  /// Asks for confirmation, then deletes the trip if it belongs to the current
  /// user. Returns true when the trip was deleted.
  static Future<bool> confirmAndDelete(
    BuildContext context,
    String tripId,
    String title,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: Text('This will permanently remove "$title" for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final ref = FirebaseFirestore.instance.collection('trips').doc(tripId);
      final snap = await ref.get();
      if (user == null || snap.data()?['userId'] != user.uid) {
        throw Exception('You can only delete your own trips.');
      }
            // Comments live in a subcollection, so delete them together with the trip.
      final comments = await ref.collection('comments').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final c in comments.docs) {
        batch.delete(c.reference);
      }
      batch.delete(ref);
      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted')),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete the trip: $e')),
        );
      }
      return false;
    }
  }
}