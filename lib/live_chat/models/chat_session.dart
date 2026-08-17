/// A shared-transcript session as returned by `GET /sessions`. Not tied to a
/// single agent (v12 §6.7): [agentId] is the session's *initial* agent and
/// [participantAgents] lists every agent that has taken a turn.
class ChatSession {
  final String sessionId;
  final String? agentId;
  final String? account;
  final String? email;
  final String? modelId;
  final String? status;
  final String? inputMode;
  final DateTime? createdAt;

  /// The server-written display label: the model names the session once its
  /// first turn completes (`session_named` frame / `GET /sessions.title`) and
  /// the title never changes afterwards, so it is safe to cache. Null while
  /// the first turn hasn't finished — fall back to [preview].
  final String? title;
  final String? preview;

  /// Every agent that produced a turn in this shared-session thread.
  final List<String> participantAgents;

  const ChatSession({
    required this.sessionId,
    this.agentId,
    this.account,
    this.email,
    this.modelId,
    this.status,
    this.inputMode,
    this.createdAt,
    this.title,
    this.preview,
    this.participantAgents = const [],
  });

  bool get isStandard => inputMode == null || inputMode == 'standard';

  /// What the sessions list renders: the model-written title once named,
  /// else the first user message as a provisional label.
  String? get displayLabel {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return preview;
  }

  ChatSession copyWith({
    String? sessionId,
    String? agentId,
    String? account,
    String? email,
    String? modelId,
    String? status,
    String? inputMode,
    DateTime? createdAt,
    String? title,
    String? preview,
    List<String>? participantAgents,
  }) {
    return ChatSession(
      sessionId: sessionId ?? this.sessionId,
      agentId: agentId ?? this.agentId,
      account: account ?? this.account,
      email: email ?? this.email,
      modelId: modelId ?? this.modelId,
      status: status ?? this.status,
      inputMode: inputMode ?? this.inputMode,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      participantAgents: participantAgents ?? this.participantAgents,
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
      inputMode: json['input_mode'] as String?,
      createdAt: _parseDate(json['created_at']),
      title: json['title'] as String?,
      preview: preview,
      participantAgents: (json['participant_agents'] as List? ?? [])
          .whereType<String>()
          .toList(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is! String) return null;
    final normalized = v.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized)?.toLocal();
  }
}
