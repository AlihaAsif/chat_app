import 'package:intl/intl.dart';

class Helpers {
  // WhatsApp jaisa time format — chat list ke liye
  static String formatChatTime(DateTime? time) {
    if (time == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(time.year, time.month, time.day);

    if (msgDate == today) {
      // Aaj — sirf time (2:30 PM)
      return DateFormat('h:mm a').format(time);
    } else if (msgDate == today.subtract(const Duration(days: 1))) {
      // Kal
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      // Is hafte — din ka naam (Monday)
      return DateFormat('EEEE').format(time);
    } else {
      // Purana — date (12/03/25)
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
}