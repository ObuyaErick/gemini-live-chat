import 'package:flutter/material.dart';
import 'package:webs/ui/core/app_theme.dart';

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
    final t = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: t.accentGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: t.e2,
              ),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: t.onAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'What should we work on?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: t.text1,
              ),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "You're talking to "),
                  TextSpan(
                    text: agentName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: t.text1,
                    ),
                  ),
                  TextSpan(
                    text: subtitle?.trim().isNotEmpty == true
                        ? ' — ${subtitle!.trim()}'
                        : ' — an agent that can read files, run tools, build charts, and edit your docs.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.55, color: t.text2),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 28),
              ...actions!,
            ],
          ],
        ),
      ),
    );
  }
}
