import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_detail_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Travel Messages 💬"),
      ),
      body: currentUserId.isEmpty
          ? const Center(child: Text("Please log in to view your messages."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error loading chats: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.mark_chat_read_outlined, size: 70, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No active conversations yet!",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Browse trip posts on the Explore feed and tap 'Ask Traveler 💬' to connect with experienced travelers.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final chats = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chatData = chats[index].data() as Map<String, dynamic>;
                    final chatId = chats[index].id;

                    final List<dynamic> participants = chatData['participants'] ?? [];
                    final Map<String, dynamic> names = Map<String, dynamic>.from(chatData['participantNames'] ?? {});
                    
                    final recipientUid = participants.firstWhere(
                      (id) => id != currentUserId,
                      orElse: () => '',
                    );

                    final recipientName = names[recipientUid] ?? 'Traveler';
                    final destination = chatData['destination'] ?? 'Trip';
                    final lastMessage = chatData['lastMessage'] ?? 'No messages yet';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          child: Text(
                            recipientName.isNotEmpty ? recipientName[0].toUpperCase() : 'T',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(recipientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                destination,
                                style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailPage(
                                chatId: chatId,
                                recipientUid: recipientUid,
                                recipientName: recipientName,
                                destination: destination,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
