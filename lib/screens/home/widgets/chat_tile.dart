import 'package:flutter/material.dart';
import '../../../core/utils/helpers.dart';

class ChatTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final DateTime? time;
  final bool isUnread;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.onTap,
    this.isUnread = false,
  });

  static const Color _teal = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with initials
            CircleAvatar(
              radius: 26,
              backgroundColor: _teal.withValues(alpha: 0.12),
              child: Text(
                Helpers.getInitials(name),
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
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
                    lastMessage.isEmpty ? 'Tap to chat' : lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      // Unread ho to thoda dark aur bold
                      color: isUnread
                          ? const Color(0xFF111827)
                          : const Color(0xFF6B7280),
                      fontWeight:
                      isUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Time + unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Helpers.formatChatTime(time),
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnread ? _teal : const Color(0xFF9CA3AF),
                    fontWeight:
                    isUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 6),
                // Unread badge (teal dot)
                if (isUnread)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: _teal,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.circle,
                          size: 8, color: Colors.white),
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}