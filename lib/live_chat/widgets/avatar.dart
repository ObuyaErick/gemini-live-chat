import 'package:flutter/material.dart';
import 'package:webs/ui/core/app_theme.dart';

/// The agent avatar. By default a rounded square filled with the brand
/// gradient; can also render a status icon (e.g. error) with explicit colors.
class Avatar extends StatelessWidget {
  final IconData icon;
  final Color? bg;
  final Color? fg;
  final double size;

  const Avatar({
    super.key,
    required this.icon,
    this.bg,
    this.fg,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final useGradient = bg == null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: useGradient ? null : bg,
        gradient: useGradient ? t.accentGradient : null,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: useGradient ? t.e1 : null,
      ),
      child: Icon(icon, size: size * 0.52, color: fg ?? t.onAccent),
    );
  }
}
