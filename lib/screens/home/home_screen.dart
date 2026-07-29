import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../contacts/contacts_screen.dart';
import '../chat/chat_screen.dart';
import 'widgets/chat_tile.dart';
import '../../models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, String> _nicknames = {};
  static const Color _teal = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    _loadNicknames();
  }

  Future<void> _loadNicknames() async {
    final nicks = await _firestoreService.getMyNicknames();
    if (mounted) setState(() => _nicknames = nicks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteChat(String otherUserId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        title: const Text('Delete chat'),
        content: Text('Delete your chat with $name? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.deleteChat(otherUserId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat deleted'),
                    backgroundColor: _teal,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

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
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
                decoration: InputDecoration(
                  hintText: 'Search chats',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xFF9CA3AF), size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: Color(0xFF9CA3AF), size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                    final chatData =
                        chats[index].data() as Map<String, dynamic>;
                    final participants =
                        List<String>.from(chatData['participants'] ?? []);

                    final otherUserId = participants.firstWhere(
                      (id) => id != _firestoreService.currentUserId,
                      orElse: () => '',
                    );

                    final lastMessage = chatData['lastMessage'] ?? '';
                    final lastTime =
                        (chatData['lastMessageTime'] as Timestamp?)?.toDate();

                    final lastSenderId = chatData['lastSenderId'] ?? '';
                    final seenBy = List<String>.from(chatData['seenBy'] ?? []);
                    final isUnread = lastSenderId !=
                            _firestoreService.currentUserId &&
                        !seenBy.contains(_firestoreService.currentUserId);

                    return StreamBuilder<UserModel?>(
                      stream: _firestoreService.getUserStream(otherUserId),
                      builder: (context, userSnapshot) {
                        final user = userSnapshot.data;
                        final realName = user?.name ?? 'User';
                        final isOnline = user?.isOnline ?? false;
                        // Nickname ho to wo dikhao
                        final name = _nicknames[otherUserId]?.isNotEmpty == true
                            ? _nicknames[otherUserId]!
                            : realName;

                        if (_searchQuery.isNotEmpty &&
                            !name.toLowerCase().contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        return Dismissible(
                          key: Key(otherUserId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: const Color(0xFFB91C1C),
                            child: const Icon(Icons.delete,
                                color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            _confirmDeleteChat(otherUserId, name);
                            return false; // dialog handle karega
                          },
                          child: ChatTile(
                            name: name,
                            lastMessage: lastMessage,
                            time: lastTime,
                            isUnread: isUnread,
                            isOnline: isOnline,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    otherUserId: otherUserId,
                                    otherUserName: realName,
                                  ),
                                ),
                              );
                              _loadNicknames(); // wapas aane pe refresh
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 52,
                    color: _teal.withValues(alpha: 0.4),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_circle,
                        size: 20,
                        color: _teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No chats yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the chat button below to start a conversation with your contacts',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}