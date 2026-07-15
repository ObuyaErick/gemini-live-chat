import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';

/// Card shown when the server parks a turn on a `clarification` frame
/// (`ASK_USER` tool). The user picks answers to each batched question and
/// submits them together as a single `elicit_response`.
class ClarificationCard extends StatefulWidget {
  final PendingClarification clarification;
  /// Called with positional answers: answers[i] = chosen labels for questions[i].
  /// An empty inner list means the question was dismissed.
  final void Function(List<List<String>> answers) onSubmit;

  const ClarificationCard({
    super.key,
    required this.clarification,
    required this.onSubmit,
  });

  @override
  State<ClarificationCard> createState() => _ClarificationCardState();
}

class _ClarificationCardState extends State<ClarificationCard> {
  // Per-question selections: index → set of chosen labels
  late final List<Set<String>> _selections;

  @override
  void initState() {
    super.initState();
    _selections = List.generate(
      widget.clarification.questions.length,
      (_) => {},
    );
  }

  void _toggle(int qIndex, String label, bool multiSelect) {
    setState(() {
      if (multiSelect) {
        if (_selections[qIndex].contains(label)) {
          _selections[qIndex].remove(label);
        } else {
          _selections[qIndex].add(label);
        }
      } else {
        // Single-select: clear and set.
        if (_selections[qIndex].contains(label)) {
          _selections[qIndex].clear(); // tapping selected option deselects (dismiss)
        } else {
          _selections[qIndex] = {label};
        }
      }
    });
  }

  void _submit() {
    final answers = _selections.map((s) => s.toList()).toList();
    widget.onSubmit(answers);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = widget.clarification.questions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'CLARIFICATION • ${widget.clarification.toolName}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),

          // ── Questions ─────────────────────────────────────────────────
          for (int i = 0; i < questions.length; i++) ...[
            const SizedBox(height: 12),
            _QuestionBlock(
              question: questions[i],
              selections: _selections[i],
              onToggle: (label) =>
                  _toggle(i, label, questions[i].multiSelect),
            ),
          ],

          // ── Submit ────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
              ),
              child: const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBlock extends StatelessWidget {
  final ClarificationQuestion question;
  final Set<String> selections;
  final void Function(String label) onToggle;

  const _QuestionBlock({
    required this.question,
    required this.selections,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.question,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: question.options.map((opt) {
            final selected = selections.contains(opt.label);
            return FilterChip(
              label: Text(opt.label),
              selected: selected,
              onSelected: (_) => onToggle(opt.label),
              tooltip: opt.description,
              showCheckmark: question.multiSelect,
              selectedColor:
                  theme.colorScheme.secondary.withValues(alpha: 0.2),
              checkmarkColor: theme.colorScheme.secondary,
              labelStyle: TextStyle(
                fontSize: 12,
                color: selected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: selected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.outlineVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          }).toList(),
        ),
      ],
    );
  }
}
