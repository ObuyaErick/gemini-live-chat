import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/ui/core/app_theme.dart';

/// Shown when the agent parks a turn awaiting confirmation for a consequential
/// action. Warning-toned, with a left accent rail — clearly a "stop and
/// decide" affordance distinct from normal chat.
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
    final t = context.tokens;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.warningSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: t.warning),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: t.warningSoft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 15, color: t.warning),
                const SizedBox(width: 8),
                Text(
                  'Confirm before I proceed',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.text1,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.summary,
                  style: TextStyle(fontSize: 13.5, height: 1.5, color: t.text1),
                ),
                if (action.parameters.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: t.bg2,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in action.parameters.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${e.key}: ',
                                    style: AppTheme.mono(
                                      size: 11.5,
                                      weight: FontWeight.w400,
                                      color: t.text3,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${e.value}',
                                    style: AppTheme.mono(
                                      size: 11.5,
                                      weight: FontWeight.w400,
                                      color: t.text2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.text2,
                          side: BorderSide(color: t.borderStrong),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onConfirm,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Confirm'),
                        style: FilledButton.styleFrom(
                          backgroundColor: t.accent,
                          foregroundColor: t.onAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
