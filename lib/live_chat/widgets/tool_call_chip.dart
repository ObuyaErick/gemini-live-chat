import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';

class ToolCallChip extends StatelessWidget {
  final List<ToolEvent> events;

  const ToolCallChip({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final pending = events.lastWhere(
      (e) => e.result == null,
      orElse: () => events.last,
    );
    final isDone = pending.result != null;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEDEEF2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDone ? Icons.check_circle_outline : Icons.sync_rounded,
              size: 16,
              color: const Color(0xFF4B5563),
            ),
            const SizedBox(width: 8),
            Text(
              isDone ? '${pending.name} → done' : 'Calling ${pending.name}...',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
