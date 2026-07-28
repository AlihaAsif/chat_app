import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../core/utils/helpers.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _firestoreService = FirestoreService();
  static const Color _teal = Color(0xFF0F766E);

  UserModel? _user;
  String _nickname = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _firestoreService.getUserById(widget.userId);
    final nicknames = await _firestoreService.getMyNicknames();
    if (!mounted) return;
    setState(() {
      _user = user;
      _nickname = nicknames[widget.userId] ?? '';
      _loading = false;
    });
  }

  void _editNickname() {
    final controller = TextEditingController(text: _nickname);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        title: const Text('Set nickname'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter a nickname',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _teal, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newNick = controller.text.trim();
              if (newNick.isEmpty) {
                await _firestoreService.removeNickname(widget.userId);
              } else {
                await _firestoreService.setNickname(widget.userId, newNick);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        title: const Text('Clear chat'),
        content: const Text(
            'This will delete all messages in this chat. Continue?'),
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
              await _firestoreService.clearChat(widget.userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat cleared'),
                    backgroundColor: _teal,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _nickname.isNotEmpty
        ? _nickname
        : (_user?.name ?? 'User');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Contact Info',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            CircleAvatar(
              radius: 50,
              backgroundColor: _teal.withValues(alpha: 0.12),
              child: Text(
                Helpers.getInitials(displayName),
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.w700,
                  fontSize: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _user?.email ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(height: 1, color: Color(0xFFF1F1F1)),

            // Nickname row — edit
            ListTile(
              leading: const Icon(Icons.badge_outlined,
                  color: _teal, size: 22),
              title: const Text('Nickname',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF))),
              subtitle: Text(
                _nickname.isEmpty ? 'None set' : _nickname,
                style: TextStyle(
                  fontSize: 15,
                  color: _nickname.isEmpty
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF111827),
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(Icons.edit_outlined,
                  color: Color(0xFF9CA3AF), size: 20),
              onTap: _editNickname,
            ),
            const Divider(
                height: 1, indent: 56, color: Color(0xFFF1F1F1)),

            // Real name row (read-only)
            ListTile(
              leading: const Icon(Icons.person_outline,
                  color: _teal, size: 22),
              title: const Text('Real name',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF))),
              subtitle: Text(
                _user?.name ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Divider(
                height: 1, indent: 56, color: Color(0xFFF1F1F1)),

            // Email row (read-only)
            ListTile(
              leading: const Icon(Icons.email_outlined,
                  color: _teal, size: 22),
              title: const Text('Email',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF))),
              subtitle: Text(
                _user?.email ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F1F1)),

            const SizedBox(height: 24),

            // Clear chat button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _confirmClearChat,
                  icon: const Icon(Icons.delete_sweep_outlined,
                      color: Color(0xFFB91C1C), size: 20),
                  label: const Text(
                    'Clear chat',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFB91C1C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}