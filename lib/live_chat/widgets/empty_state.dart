import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String agentName;
  final String? subtitle;
  final List<Widget>? actions;

  const EmptyState({
    super.key,
    required this.agentName,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: double.infinity),
        Icon(
          Icons.bar_chart_rounded,
          size: 48,
          color: colorScheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        Text(
          agentName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle?.trim().isNotEmpty == true
              ? subtitle!.trim()
              : 'Ask me anything.',
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),
        ...?actions,
      ],
    );
  }
}
