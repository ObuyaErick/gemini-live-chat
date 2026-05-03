import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';

class ActionConfirmationCard extends StatelessWidget {
  final PendingAction action;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ActionConfirmationCard({
    super.key,
    required this.action,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 16,
                color: Color(0xFF8A6D3B),
              ),
              const SizedBox(width: 8),
              Text(
                'CONFIRM ACTION • ${action.toolName}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF8A6D3B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            action.summary,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF5C4A1A),
            ),
          ),
          if (action.parameters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              action.parameters.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('  •  '),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8A6D3B),
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Confirm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A6D3B),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
