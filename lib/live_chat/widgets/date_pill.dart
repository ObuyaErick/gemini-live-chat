import 'package:flutter/material.dart';
import 'package:webs/ui/core/app_theme.dart';

class DatePill extends StatelessWidget {
  final String text;
  const DatePill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border),
      ),
      child: Text(
        text,
        style: AppTheme.mono(
          size: 10,
          weight: FontWeight.w600,
          color: t.text3,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
