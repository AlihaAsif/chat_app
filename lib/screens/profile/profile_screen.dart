import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../core/utils/helpers.dart';
import '../auth_wrapper.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: FutureBuilder<UserModel?>(
        future: firestoreService.getUserById(firestoreService.currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }

          final user = snapshot.data;
          final name = user?.name ?? 'User';
          final email = user?.email ?? '';

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Big avatar with initials
                CircleAvatar(
                  radius: 50,
                  backgroundColor: _teal.withValues(alpha: 0.12),
                  child: Text(
                    Helpers.getInitials(name),
                    style: const TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.w700,
                      fontSize: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),

                // Email
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 32),

                const Divider(height: 1, color: Color(0xFFF1F1F1)),

                // Info rows
                _buildInfoTile(Icons.person_outline, 'Name', name),
                const Divider(height: 1, indent: 56, color: Color(0xFFF1F1F1)),
                _buildInfoTile(Icons.email_outlined, 'Email', email),
                const Divider(height: 1, color: Color(0xFFF1F1F1)),

                const SizedBox(height: 32),

                // Logout button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout,
                          color: Color(0xFFB91C1C), size: 20),
                      label: const Text(
                        'Log out',
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
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: _teal, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF111827),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
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
              Navigator.pop(ctx); // dialog band karo
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // Saara stack clear karke AuthWrapper pe jao — wo login dikhayega
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                      (route) => false,
                );
              }
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}