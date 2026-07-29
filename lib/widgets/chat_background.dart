import 'package:flutter/material.dart';

class ChatBackground extends StatelessWidget {
  final Widget child;
  const ChatBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F6F5), // halka off-white base
      child: CustomPaint(
        painter: _DotsPainter(),
        child: child,
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F766E).withValues(alpha: 0.08) // zyada visible teal
      ..style = PaintingStyle.fill;

    const spacing = 24.0; // dots ke beech faasla (kam = ghane)
    const radius = 2.5; // dot ka size

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        // Har doosri row thodi shift (staggered look)
        final offsetX = (y ~/ spacing) % 2 == 0 ? 0.0 : spacing / 2;
        canvas.drawCircle(Offset(x + offsetX, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}