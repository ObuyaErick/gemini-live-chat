import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/ui/core/app_theme.dart';

/// Shown when the agent parks a turn awaiting confirmation for a consequential
/// action. Warning-toned, with a left accent rail — clearly a "stop and
/// decide" affordance distinct from normal chat. Offers three verdicts:
/// confirm, cancel, and amend ("adjust this before running it"), the last of
/// which expands an optional free-text field for what should change.
class ActionConfirmationCard extends StatefulWidget {
  final PendingAction action;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// Send an `action_amend` verdict. A null [instruction] is a bare amend —
  /// the model asks what to change.
  final void Function(String? instruction) onAmend;

  const ActionConfirmationCard({
    super.key,
    required this.action,
    required this.onConfirm,
    required this.onCancel,
    required this.onAmend,
  });

  @override
  State<ActionConfirmationCard> createState() => _ActionConfirmationCardState();
}

class _ActionConfirmationCardState extends State<ActionConfirmationCard> {
  final TextEditingController _amendController = TextEditingController();
  bool _amendOpen = false;

  @override
  void dispose() {
    _amendController.dispose();
    super.dispose();
  }

  // An empty submit is a valid bare amend — the model asks what to change.
  void _submitAmend() {
    final text = _amendController.text.trim();
    widget.onAmend(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final action = widget.action;
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
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 15,
                          color: t.warning,
                        ),
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
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: t.text1,
                          ),
                        ),
                        // What the action will actually do: server-resolved
                        // settings the model never supplies (destination,
                        // folder, theme, …). Render label/display in the
                        // authored order; `value` is an identifier, never
                        // shown. Nothing renders when the tool declares none.
                        if (action.settings.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: t.warningSoft.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: t.warningSoft),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final s in action.settings)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 110,
                                          child: Text(
                                            s.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: t.text3,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            s.display,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: t.text1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 1,
                                    ),
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
                                onPressed: widget.onCancel,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: t.text2,
                                  side: BorderSide(color: t.borderStrong),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Third verdict: adjust instead of run/drop. With
                            // server-resolved settings on show, the natural
                            // ask is tweaking them; otherwise it is a general
                            // "not like this" escape hatch.
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _amendOpen = !_amendOpen),
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: Text(
                                  action.settings.isNotEmpty
                                      ? 'Tweak settings'
                                      : 'Do it differently',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: t.accent,
                                  side: BorderSide(color: t.borderStrong),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: widget.onConfirm,
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Confirm'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: t.accent,
                                  foregroundColor: t.onAccent,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_amendOpen) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.only(left: 12, right: 4),
                            decoration: BoxDecoration(
                              color: t.bg2,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: t.borderStrong),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _amendController,
                                    autofocus: true,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: t.text1,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      hintText:
                                          'What should change? (optional)',
                                      hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: t.text3,
                                      ),
                                    ),
                                    onSubmitted: (_) => _submitAmend(),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _submitAmend,
                                  tooltip: 'Send',
                                  icon: Icon(
                                    Icons.send_rounded,
                                    size: 16,
                                    color: t.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
