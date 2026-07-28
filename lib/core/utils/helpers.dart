import 'package:intl/intl.dart';

class Helpers {
  // WhatsApp jaisa time format — chat list ke liye
  static String formatChatTime(DateTime? time) {
    if (time == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(time.year, time.month, time.day);

    if (msgDate == today) {
      return DateFormat('h:mm a').format(time);
    } else if (msgDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      return DateFormat('EEEE').format(time);
    } else {
      return DateFormat('dd/MM/yy').format(time);
    }
  }

  // Chat bubble ke liye sirf time (2:30 PM)
  static String formatMessageTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  // Naam ka pehla letter — avatar ke liye
  static String getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  // Date separator ke liye label — "Today", "Yesterday", ya date
  static String formatDateSeparator(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(time.year, time.month, time.day);

    if (msgDate == today) {
      return 'Today';
    } else if (msgDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(time);
    }
  }

  // Do dates same din ke hain?
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // "last seen" ke liye — "online", "last seen today at 2:30 PM", etc.
  static String formatLastSeen(bool isOnline, DateTime? lastSeen) {
    if (isOnline) return 'online';
    if (lastSeen == null) return 'offline';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final seenDate = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
    final timeStr = DateFormat('h:mm a').format(lastSeen);

    if (seenDate == today) {
      return 'last seen today at $timeStr';
    } else if (seenDate == today.subtract(const Duration(days: 1))) {
      return 'last seen yesterday at $timeStr';
    } else {
      return 'last seen ${DateFormat('dd/MM/yy').format(lastSeen)}';
    }
  }
}