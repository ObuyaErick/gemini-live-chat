import 'dart:typed_data';

enum MessageRole { user, assistant }

enum MessageStatus { streaming, complete, error }

class ChatMessage {
  final MessageRole role;
  String content;
  MessageStatus status;
  final DateTime createdAt;
  final Uint8List? imageBytes;
  final String? imageMimeType;
  List<Attachment> attachments;

  ChatMessage({
    required this.role,
    this.content = '',
    this.status = MessageStatus.complete,
    DateTime? createdAt,
    this.imageBytes,
    this.imageMimeType,
    this.attachments = const [],
  }) : createdAt = createdAt ?? DateTime.now();
}

class Attachment {
  final String fileId;
  final String filename;
  final String mimeType;
  final String url;
  final int? sizeBytes;

  const Attachment({
    required this.fileId,
    required this.filename,
    required this.mimeType,
    required this.url,
    this.sizeBytes,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      fileId: (json['file_id'] as String?) ?? '',
      filename: (json['filename'] as String?) ?? 'attachment',
      mimeType: (json['mime_type'] as String?) ?? 'application/octet-stream',
      url: (json['url'] as String?) ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
    );
  }

  bool get isPlotlyJson => mimeType == 'application/json';
}

class ToolEvent {
  final String name;
  final Map<String, dynamic>? args;
  final Map<String, dynamic>? result;
  final DateTime createdAt;

  ToolEvent({required this.name, this.args, this.result, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();
}

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

class ChatContextSelection {
  final String type;
  final String id;
  final String? label;

  const ChatContextSelection({
    required this.type,
    required this.id,
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    if (label != null) 'label': label,
  };
}

class ChatSession {
  final String sessionId;
  final String? agentId;
  final String? account;
  final String? email;
  final String? modelId;
  final String? status;
  final DateTime? createdAt;
  final String? preview;

  const ChatSession({
    required this.sessionId,
    this.agentId,
    this.account,
    this.email,
    this.modelId,
    this.status,
    this.createdAt,
    this.preview,
  });

  ChatSession copyWith({
    String? sessionId,
    String? agentId,
    String? account,
    String? email,
    String? modelId,
    String? status,
    DateTime? createdAt,
    String? preview,
  }) {
    return ChatSession(
      sessionId: sessionId ?? this.sessionId,
      agentId: agentId ?? this.agentId,
      account: account ?? this.account,
      email: email ?? this.email,
      modelId: modelId ?? this.modelId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      preview: preview ?? this.preview,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List?) ?? const [];
    String? preview;
    for (final m in messages) {
      if (m is Map) {
        final role = m['role'];
        final content = m['content'];
        if (role == 'user' && content is String && content.trim().isNotEmpty) {
          preview = content;
          break;
        }
      }
    }
    
    return ChatSession(
      sessionId: json['session_id'] as String,
      agentId: json['agent_id'] as String?,
      account: json['account'] as String?,
      email: json['email'] as String?,
      modelId: json['model_id'] as String?,
      status: json['status'] as String?,
      createdAt: _parseDate(json['created_at']),
      preview: preview,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is! String) return null;
    final normalized = v.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized)?.toLocal();
  }
}

class ChatContext {
  final String module;
  final String page;
  final String? path;
  final String? title;
  final Map<String, dynamic>? params;
  final ChatContextSelection? selection;

  const ChatContext({
    required this.module,
    required this.page,
    this.path,
    this.title,
    this.params,
    this.selection,
  });

  Map<String, dynamic> toJson() => {
    'module': module,
    'page': page,
    if (path != null) 'path': path,
    if (title != null) 'title': title,
    if (params != null) 'params': params,
    if (selection != null) 'selection': selection!.toJson(),
  };
}
