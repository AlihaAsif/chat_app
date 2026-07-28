import 'package:flutter/material.dart';

class AppLogoHeader extends StatelessWidget {
  final String subtitle;
  const AppLogoHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo image
        Image.asset(
          'assets/icon/app_icon.png',
          width: 96,
          height: 96,
        ),
        const SizedBox(height: 8),

        // App name
        const Text(
          'Chatt App',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F766E),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle (login/signup ke liye alag text)
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}