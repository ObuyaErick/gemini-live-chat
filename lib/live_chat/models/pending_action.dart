/// A Tier-3 action awaiting the user's confirm/cancel decision. While set, the
/// server has parked the turn until we reply with `action_confirm` or
/// `action_cancel`.
class PendingAction {
  final String toolName;
  final String summary;
  final Map<String, dynamic> parameters;
  final DateTime createdAt;

  PendingAction({
    required this.toolName,
    required this.summary,
    required this.parameters,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
