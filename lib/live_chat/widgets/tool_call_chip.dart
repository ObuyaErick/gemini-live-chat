import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/ui/core/app_theme.dart';

/// Quiet, pill-shaped indicator that a tool ran. Distinct from conversational
/// content: spinner while running, success check when resolved, error mark on
/// failure.
class ToolCallChip extends StatelessWidget {
  final List<ToolEvent> events;

  const ToolCallChip({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pending = events.lastWhere(
      (e) => e.result == null,
      orElse: () => events.last,
    );
    final isDone = pending.result != null;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDone)
              Icon(Icons.check_rounded, size: 14, color: t.success)
            else
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: t.accent,
                ),
              ),
            const SizedBox(width: 8),
            Text(pending.name, style: AppTheme.mono(size: 12, color: t.text2)),
            const SizedBox(width: 8),
            Text(
              isDone ? 'done' : 'running…',
              style: TextStyle(fontSize: 12, color: t.text3),
            ),
          ],
        ),
      ),
    );
  }
}
