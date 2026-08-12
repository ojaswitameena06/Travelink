import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String email = user?.email ?? "User Email";
    final String uid = user?.uid ?? "";

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 👤 User Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text("Logout"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => LoginPage()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Divider(thickness: 1),

            // 🎯 My Bucket List Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: const [
                  Icon(Icons.bookmark, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    "My Bucket List 🎯",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            if (uid.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Please log in to see your bucket list."),
              )
            else
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('trips')
                    .where('bookmarks', arrayContains: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text("Error loading bucket list: ${snapshot.error}"),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        "Your bucket list is empty!\nTap the bookmark icon 🔖 on trips in Explore to save them here.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final savedTrips = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: savedTrips.length,
                    itemBuilder: (context, index) {
                      final trip = savedTrips[index].data() as Map<String, dynamic>;
                      final tripId = savedTrips[index].id;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (trip['image'] != null && trip['image'].toString().isNotEmpty)
                                ? Image.network(
                                    trip['image'],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 25),
                                  ),
                          ),
                          title: Text(
                            trip['title'] ?? 'No title',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            trip['description'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            tooltip: "Remove from Bucket List",
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('trips').doc(tripId).update({
                                'bookmarks': FieldValue.arrayRemove([uid])
                              });
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
