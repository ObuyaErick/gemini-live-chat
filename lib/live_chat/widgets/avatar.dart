import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;

  const Avatar({
    super.key,
    required this.icon,
    this.bg = const Color(0xFFEDEEF2),
    this.fg = const Color(0xFF4B5563),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: fg),
    );
  }
}
