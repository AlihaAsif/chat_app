import 'package:flutter/material.dart';
import '../../../core/utils/helpers.dart';

class ChatTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final DateTime? time;
  final bool isUnread;
  final bool isOnline;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.onTap,
    this.isUnread = false,
    this.isOnline = false,
  });

  static const Color _teal = Color(0xFF0F766E);

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF0F766E), // Teal
      const Color(0xFF0284C7), // Sky Blue
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFF7C3AED), // Violet
      const Color(0xFFDB2777), // Pink
      const Color(0xFFDC2626), // Red
      const Color(0xFFEA580C), // Orange
      const Color(0xFF16A34A), // Green
    ];
    if (name.isEmpty) return colors[0];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isUnread ? _teal.withValues(alpha: 0.05) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar with initials and online dot
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: _getAvatarColor(name),
                    child: Text(
                      Helpers.getInitials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
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
      ),
    );
  }
}