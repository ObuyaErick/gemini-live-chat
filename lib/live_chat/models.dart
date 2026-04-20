enum MessageRole { user, assistant }

enum MessageStatus { streaming, complete, error }

class ChatMessage {
  final MessageRole role;
  String content;
  MessageStatus status;
  final DateTime createdAt;

  ChatMessage({
    required this.role,
    this.content = '',
    this.status = MessageStatus.complete,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class ToolEvent {
  final String name;
  final Map<String, dynamic>? args;
  final Map<String, dynamic>? result;
  final DateTime createdAt;

  ToolEvent({required this.name, this.args, this.result, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();
}
