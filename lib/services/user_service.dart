import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  final String uid;
  final String name;
  final String? photoUrl;
  final String bio;
  final bool isNamed;

  const UserProfile({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.bio = '',
    this.isNamed = false,
  });

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

class UserService {
  static final Map<String, UserProfile> _cache = {};

  static String fallbackName(String uid) =>
      'Traveler ${uid.length >= 4 ? uid.substring(0, 4) : uid}';

  static UserProfile? cached(String uid) => _cache[uid];

  static Future<UserProfile> getProfile(String uid) async {
    if (uid.isEmpty) return const UserProfile(uid: '', name: 'Traveler');

    final hit = _cache[uid];
    if (hit != null) return hit;

    try {
      final doc = await FirebaseFirestore.instance.collection('profiles').doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};
      final name = (data['displayName'] ?? '').toString().trim();
      final photo = (data['photoUrl'] ?? '').toString().trim();

      final profile = UserProfile(
        uid: uid,
        name: name.isNotEmpty ? name : fallbackName(uid),
        photoUrl: photo.isNotEmpty ? photo : null,
        bio: (data['bio'] ?? '').toString(),
        isNamed: name.isNotEmpty,
      );
      _cache[uid] = profile;
      return profile;
    } catch (_) {
      return UserProfile(uid: uid, name: fallbackName(uid));
    }
  }

  static void clearCache([String? uid]) {
    if (uid == null) {
      _cache.clear();
    } else {
      _cache.remove(uid);
    }
  }

  static Future<void> saveMyProfile({
    required String name,
    required String bio,
    String? photoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please log in first.');

    final data = <String, dynamic>{
      'displayName': name,
      'bio': bio,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (photoUrl != null) data['photoUrl'] = photoUrl;

    await FirebaseFirestore.instance
        .collection('profiles')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));

    // Keep Firebase Auth in sync so reviews and buddy plans use the real name.
    await user.updateDisplayName(name);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);

    clearCache(user.uid);
  }
}