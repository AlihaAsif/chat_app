import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../contacts/contacts_screen.dart';
import '../chat/chat_screen.dart';
import 'widgets/chat_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  static const Color _teal = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Chatt App',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getMyChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _teal),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Something went wrong.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 82,
              color: Color(0xFFF1F1F1),
            ),
            itemBuilder: (context, index) {
              final chatData = chats[index].data() as Map<String, dynamic>;
              final participants =
              List<String>.from(chatData['participants'] ?? []);

              final otherUserId = participants.firstWhere(
                    (id) => id != _firestoreService.currentUserId,
                orElse: () => '',
              );

              final lastMessage = chatData['lastMessage'] ?? '';
              final lastTime =
              (chatData['lastMessageTime'] as Timestamp?)?.toDate();

              // Unread check: last message doosre ne bheja + maine nahi dekha
              final lastSenderId = chatData['lastSenderId'] ?? '';
              final seenBy = List<String>.from(chatData['seenBy'] ?? []);
              final isUnread =
                  lastSenderId != _firestoreService.currentUserId &&
                      !seenBy.contains(_firestoreService.currentUserId);

              return FutureBuilder(
                future: _firestoreService.getUserById(otherUserId),
                builder: (context, userSnapshot) {
                  final user = userSnapshot.data;
                  final name = user?.name ?? 'User';

                  return ChatTile(
                    name: name,
                    lastMessage: lastMessage,
                    time: lastTime,
                    isUnread: isUnread,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: otherUserId,
                            otherUserName: name,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          );
        },
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.chat_bubble_outline,
                color: _teal, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap the chat button to start a conversation',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}