import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_avatar.dart';

class TripComments extends StatefulWidget {
  final String tripId;
  final String tripOwnerId;

  const TripComments({super.key, required this.tripId, required this.tripOwnerId});

  @override
  State<TripComments> createState() => _TripCommentsState();
}

class _TripCommentsState extends State<TripComments> {
  final _controller = TextEditingController();
  bool _sending = false;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  CollectionReference<Map<String, dynamic>> get _comments => FirebaseFirestore.instance
      .collection('trips')
      .doc(widget.tripId)
      .collection('comments');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return 'just now';
    final d = ts.toDate();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _show('Please log in to comment.');
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _comments.add({
        'userId': user.uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _controller.clear();
    } catch (e) {
      _show('Could not post your comment: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String commentId) async {
    try {
      await _comments.doc(commentId).delete();
    } catch (e) {
      _show('Could not delete the comment: $e');
    }
  }

  Widget _inputRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            maxLength: 300,
            maxLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _sending
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.send, color: Colors.blueAccent),
                tooltip: 'Post comment',
                onPressed: _send,
              ),
      ],
    );
  }

  Widget _commentTile(QueryDocumentSnapshot<Map<String, dynamic>> doc, String? uid) {
    final data = doc.data();
    final authorId = (data['userId'] ?? '').toString();
    // The commenter can delete their own comment; the trip owner can delete any.
    final canDelete = uid != null && (authorId == uid || widget.tripOwnerId == uid);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(uid: authorId, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: UserName(
                        uid: authorId,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(data['createdAt'] as Timestamp?),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text((data['text'] ?? '').toString()),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete comment',
              onPressed: () => _delete(doc.id),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _comments.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comments (${docs.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _inputRow(),
            const SizedBox(height: 8),
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snap.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Could not load comments: ${snap.error}'),
              )
            else if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No comments yet. Start the conversation!',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...docs.map((d) => _commentTile(d, uid)),
          ],
        );
      },
    );
  }
}