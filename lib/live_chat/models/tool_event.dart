/// A tool invocation observed on the wire: a `tool_call` frame, optionally
/// completed by its matching `tool_result` (which fills [result]).
class ToolEvent {
  final String name;
  final Map<String, dynamic>? args;
  final Map<String, dynamic>? result;
  final DateTime createdAt;

  ToolEvent({required this.name, this.args, this.result, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();
}
