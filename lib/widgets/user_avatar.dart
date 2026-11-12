import 'package:flutter/material.dart';
import '../services/user_service.dart';

/// Shows a user's profile photo, or their initial if they have none.
class UserAvatar extends StatelessWidget {
  final String uid;
  final double radius;

  const UserAvatar({super.key, required this.uid, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: UserService.getProfile(uid),
      initialData: UserService.cached(uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final photo = profile?.photoUrl;
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.blueAccent.withOpacity(0.2),
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null
              ? Text(
                  profile?.initial ?? '',
                  style: TextStyle(
                    fontSize: radius * 0.9,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// Shows a user's display name, or "Traveler xxxx" if they haven't set one.
class UserName extends StatelessWidget {
  final String uid;
  final TextStyle? style;

  const UserName({super.key, required this.uid, this.style});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: UserService.getProfile(uid),
      initialData: UserService.cached(uid),
      builder: (context, snapshot) {
        return Text(
          snapshot.data?.name ?? UserService.fallbackName(uid),
          style: style,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}