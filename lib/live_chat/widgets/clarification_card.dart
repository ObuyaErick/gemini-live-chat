import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/ui/core/app_theme.dart';

/// Card shown when the server parks a turn on a `clarification` frame
/// (`ASK_USER` tool). The user picks answers to each batched question — or
/// describes their own in the per-question "Other" field; every question
/// accepts free text — and submits them together as a single `elicit_response`.
class ClarificationCard extends StatefulWidget {
  final PendingClarification clarification;

  /// Called with positional answers: answers[i] = chosen labels and/or the
  /// user's own words for questions[i] (the server partitions them by label
  /// match). An empty inner list means the question was dismissed.
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
  late final List<Set<String>> _selections;
  late final List<TextEditingController> _customControllers;
  late final List<bool> _customOpen;

  @override
  void initState() {
    super.initState();
    final count = widget.clarification.questions.length;
    _selections = List.generate(count, (_) => {});
    _customControllers = List.generate(count, (_) => TextEditingController());
    _customOpen = List.filled(count, false);
  }

  @override
  void dispose() {
    for (final c in _customControllers) {
      c.dispose();
    }
    super.dispose();
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
        if (_selections[qIndex].contains(label)) {
          _selections[qIndex].clear();
        } else {
          _selections[qIndex] = {label};
          // Single-select means one answer total — picking a label
          // supersedes whatever was typed.
          _customControllers[qIndex].clear();
          _customOpen[qIndex] = false;
        }
      }
    });
  }

  void _toggleCustom(int qIndex, bool multiSelect) {
    setState(() {
      _customOpen[qIndex] = !_customOpen[qIndex];
      if (!_customOpen[qIndex]) {
        _customControllers[qIndex].clear();
      } else if (!multiSelect) {
        // Symmetric with _toggle: describing your own answer supersedes a pick.
        _selections[qIndex].clear();
      }
    });
  }

  void _submit() {
    final answers = <List<String>>[];
    for (int i = 0; i < _selections.length; i++) {
      final answer = _selections[i].toList();
      final custom = _customControllers[i].text.trim();
      if (custom.isNotEmpty) answer.add(custom);
      answers.add(answer);
    }
    widget.onSubmit(answers);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final questions = widget.clarification.questions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 16, color: t.accent),
              const SizedBox(width: 8),
              Text(
                'A couple of quick questions',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: t.text1,
                ),
              ),
            ],
          ),
          for (int i = 0; i < questions.length; i++) ...[
            const SizedBox(height: 16),
            _QuestionBlock(
              question: questions[i],
              selections: _selections[i],
              onToggle: (label) => _toggle(i, label, questions[i].multiSelect),
              customOpen: _customOpen[i],
              customController: _customControllers[i],
              onToggleCustom: () => _toggleCustom(i, questions[i].multiSelect),
              onCustomChanged: questions[i].multiSelect
                  ? null
                  : (text) {
                      // One answer total: typing supersedes a picked label.
                      if (text.trim().isNotEmpty && _selections[i].isNotEmpty) {
                        setState(() => _selections[i].clear());
                      }
                    },
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.onAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Submit answers'),
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
  final bool customOpen;
  final TextEditingController customController;
  final VoidCallback onToggleCustom;
  final void Function(String text)? onCustomChanged;

  const _QuestionBlock({
    required this.question,
    required this.selections,
    required this.onToggle,
    required this.customOpen,
    required this.customController,
    required this.onToggleCustom,
    this.onCustomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: question.question),
              if (question.multiSelect)
                TextSpan(
                  text: '  (multi)',
                  style: TextStyle(fontWeight: FontWeight.w400, color: t.text3),
                ),
            ],
          ),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: t.text1,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        if (question.multiSelect) ...[
          Column(
            children: [
              for (final opt in question.options)
                _CheckOption(
                  option: opt,
                  selected: selections.contains(opt.label),
                  onTap: () => onToggle(opt.label),
                ),
            ],
          ),
          _OtherToggleRow(open: customOpen, onTap: onToggleCustom),
        ] else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in question.options)
                _PillOption(
                  label: opt.label,
                  selected: selections.contains(opt.label),
                  onTap: () => onToggle(opt.label),
                ),
              _PillOption(
                label: 'Other…',
                selected: customOpen,
                onTap: onToggleCustom,
              ),
            ],
          ),
        if (customOpen)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: customController,
              autofocus: true,
              onChanged: onCustomChanged,
              style: TextStyle(fontSize: 12.5, color: t.text1),
              decoration: InputDecoration(
                hintText: 'Describe it in your own words…',
                hintStyle: TextStyle(fontSize: 12.5, color: t.text3),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                filled: true,
                fillColor: t.bg2,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: t.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: t.accent),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The multi-select variant of the "Other" affordance — a quiet row beneath
/// the checkboxes, matching their layout language.
class _OtherToggleRow extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;

  const _OtherToggleRow({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                open ? Icons.close_rounded : Icons.edit_outlined,
                size: 13,
                color: t.text3,
              ),
              const SizedBox(width: 8),
              Text(
                open ? 'Remove my own answer' : 'Add my own answer…',
                style: TextStyle(fontSize: 12, color: t.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? t.accent : t.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: t.text1,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckOption extends StatelessWidget {
  final ClarificationOption option;
  final bool selected;
  final VoidCallback onTap;

  const _CheckOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected ? t.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: selected ? t.accentBorder : t.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: selected ? t.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: selected
                        ? null
                        : Border.all(color: t.borderStrong, width: 1.5),
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded, size: 11, color: t.onAccent)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: t.text1,
                        ),
                      ),
                      if (option.description != null &&
                          option.description!.isNotEmpty)
                        Text(
                          option.description!,
                          style: TextStyle(fontSize: 11, color: t.text3),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
