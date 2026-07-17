/// One selectable option in a clarification question.
class ClarificationOption {
  final String label;
  final String? description;
  const ClarificationOption({required this.label, this.description});

  factory ClarificationOption.fromJson(Map<String, dynamic> json) =>
      ClarificationOption(
        label: (json['label'] as String?) ?? '',
        description: json['description'] as String?,
      );
}

/// A single question in an `ASK_USER` clarification. [multiSelect] chooses
/// between a single-choice and a multi-select picker.
class ClarificationQuestion {
  final String question;
  final List<ClarificationOption> options;
  final bool multiSelect;

  const ClarificationQuestion({
    required this.question,
    required this.options,
    required this.multiSelect,
  });

  factory ClarificationQuestion.fromJson(Map<String, dynamic> json) =>
      ClarificationQuestion(
        question: (json['question'] as String?) ?? '',
        options: (json['options'] as List? ?? [])
            .whereType<Map>()
            .map((o) => ClarificationOption.fromJson(o.cast()))
            .toList(),
        multiSelect: (json['multi_select'] as bool?) ?? false,
      );
}

/// A batched `ASK_USER` clarification awaiting the user's selections. The turn
/// is parked until we reply with a positional `elicit_response`.
class PendingClarification {
  final String toolName;
  final List<ClarificationQuestion> questions;

  const PendingClarification({required this.toolName, required this.questions});
}
