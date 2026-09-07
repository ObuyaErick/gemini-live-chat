/// A Tier-3 action awaiting the user's verdict. While set, the server has
/// parked the turn until we reply with `action_confirm`, `action_cancel`, or
/// `action_amend` (adjust it — nothing runs, the model re-proposes).
class PendingAction {
  final String toolName;
  final String summary;
  final Map<String, dynamic> parameters;

  /// What the action will actually do — server-resolved values the model never
  /// supplies (destination, folder, theme, …), ordered for rendering. Show
  /// [ActionSetting.label] / [ActionSetting.display]; never render `value`.
  /// Empty when the tool declares none — render nothing in that case.
  final List<ActionSetting> settings;
  final DateTime createdAt;

  PendingAction({
    required this.toolName,
    required this.summary,
    required this.parameters,
    this.settings = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// One row of an `action_confirmation.settings` list.
class ActionSetting {
  final String key;
  final String label;

  /// The identifier the server will execute with (e.g. a group id). Kept for a
  /// future "tweak settings" flow — not for display.
  final String value;

  /// The human-readable form (e.g. "Engineering") — this is what gets rendered.
  final String display;

  const ActionSetting({
    required this.key,
    required this.label,
    required this.value,
    required this.display,
  });

  factory ActionSetting.fromJson(Map<String, dynamic> json) {
    return ActionSetting(
      key: (json['key'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      value: '${json['value'] ?? ''}',
      display: (json['display'] as String?) ?? '${json['value'] ?? ''}',
    );
  }
}

/// Lifecycle of a confirmed action, driven by `action_result` frames: the
/// server acks the confirmation with `running` (a real action — a publish, a
/// bulk write — routinely takes ten seconds or more), then reports a terminal
/// `ok` / `error` / `cancelled`. An `action_amend` verdict skips `running`
/// entirely: nothing executes, and the terminal `amended` (with the user's
/// request in `reason`) closes the dialog while the turn keeps going —
/// typically toward a fresh confirmation with adjusted settings.
enum ActionRunStatus { running, ok, error, cancelled, amended }

/// The `action_result` payload — the response half of `action_confirmation`,
/// keyed by [toolName] the same way `tool_call`/`tool_result` pair up.
class ActionRun {
  final String toolName;
  final ActionRunStatus status;
  final String? summary;
  final Map<String, dynamic>? result;
  final String? error;
  final String? reason;
  final int? latencyMs;

  const ActionRun({
    required this.toolName,
    required this.status,
    this.summary,
    this.result,
    this.error,
    this.reason,
    this.latencyMs,
  });

  factory ActionRun.fromJson(Map<String, dynamic> json) {
    return ActionRun(
      toolName: (json['tool_name'] as String?) ?? 'action',
      status: switch (json['status'] as String?) {
        'running' => ActionRunStatus.running,
        'error' => ActionRunStatus.error,
        'cancelled' => ActionRunStatus.cancelled,
        'amended' => ActionRunStatus.amended,
        _ => ActionRunStatus.ok,
      },
      summary: json['summary'] as String?,
      result: (json['result'] as Map?)?.cast<String, dynamic>(),
      error: json['error'] as String?,
      reason: json['reason'] as String?,
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
    );
  }

  bool get isRunning => status == ActionRunStatus.running;
}
