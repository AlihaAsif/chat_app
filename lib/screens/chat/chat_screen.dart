import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/message_model.dart';
import '../../core/utils/helpers.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestoreService = FirestoreService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  static const Color _teal = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    _firestoreService.markChatAsSeen(widget.otherUserId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    await _firestoreService.sendMessage(
      otherUserId: widget.otherUserId,
      text: text,
    );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _showMessageOptions(MessageModel message, bool isMe) {
    if (!isMe) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFB91C1C)),
              title: const Text('Delete message',
                  style: TextStyle(color: Color(0xFFB91C1C))),
              onTap: () async {
                Navigator.pop(ctx);
                await _firestoreService.deleteMessage(
                  otherUserId: widget.otherUserId,
                  messageId: message.messageId,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Color(0xFF6B7280)),
              title: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280))),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              child: Text(
                Helpers.getInitials(widget.otherUserName),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            // Chat doc suno — seenBy check karne ke liye (ticks)
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestoreService.getChatDoc(widget.otherUserId),
              builder: (context, chatSnapshot) {
                // Doosre ne last message dekha ya nahi
                bool otherHasSeen = false;
                if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                  final chatData =
                  chatSnapshot.data!.data() as Map<String, dynamic>?;
                  final seenBy =
                  List<String>.from(chatData?['seenBy'] ?? []);
                  otherHasSeen = seenBy.contains(widget.otherUserId);
                }

                return StreamBuilder<List<MessageModel>>(
                  stream: _firestoreService.getMessages(widget.otherUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _teal),
                      );
                    }

                    final messages = snapshot.data ?? [];

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          'No messages yet.\nSay hi!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId ==
                            _firestoreService.currentUserId;

                        bool showDateSeparator = false;
                        if (index == messages.length - 1) {
                          showDateSeparator = true;
                        } else {
                          final olderMessage = messages[index + 1];
                          if (!Helpers.isSameDay(message.timestamp,
                              olderMessage.timestamp)) {
                            showDateSeparator = true;
                          }
                        }

                        return Column(
                          children: [
                            if (showDateSeparator)
                              _buildDateSeparator(message.timestamp),
                            GestureDetector(
                              onLongPress: () =>
                                  _showMessageOptions(message, isMe),
                              child: _buildMessageBubble(
                                  message, isMe, otherHasSeen),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          Helpers.formatDateSeparator(time),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      MessageModel message, bool isMe, bool otherHasSeen) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _teal : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Helpers.formatMessageTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                // Ticks — sirf mere messages pe
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    // Doosre ne dekha? double tick : single tick (sab messages pe)
                    otherHasSeen ? Icons.done_all : Icons.done,
                    size: 14,
                    color: otherHasSeen
                        ? Colors.lightBlueAccent
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _teal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}