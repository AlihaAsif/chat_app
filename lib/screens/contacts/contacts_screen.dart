import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../core/utils/helpers.dart';
import '../chat/chat_screen.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  static const Color _teal = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Select Contact',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: firestoreService.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _teal),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No other users yet.\nInvite friends to join!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 82,
              color: Color(0xFFF1F1F1),
            ),
            itemBuilder: (context, index) {
              final user = users[index];
              return InkWell(
                onTap: () {
                  // Us user ke saath chat screen kholo
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        otherUserId: user.uid,
                        otherUserName: user.name,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: _teal.withValues(alpha: 0.12),
                        child: Text(
                          Helpers.getInitials(user.name),
                          style: const TextStyle(
                            color: _teal,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}