import 'dart:convert';
import 'dart:typed_data';

enum MessageRole { user, assistant }

enum MessageStatus { streaming, complete, error }

class LocalFileAttachment {
  final String filename;
  final String mimeType;
  final Uint8List bytes;

  const LocalFileAttachment({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  String get base64Data => base64Encode(bytes);
  int get sizeBytes => bytes.length;
}

class ChatMessage {
  final MessageRole role;
  String content;
  MessageStatus status;
  final DateTime createdAt;
  final Uint8List? imageBytes;
  final String? imageMimeType;
  List<Attachment> attachments;
  final List<LocalFileAttachment> localAttachments;
  final bool isTranscript;

  ChatMessage({
    required this.role,
    this.content = '',
    this.status = MessageStatus.complete,
    DateTime? createdAt,
    this.imageBytes,
    this.imageMimeType,
    this.attachments = const [],
    this.localAttachments = const [],
    this.isTranscript = false,
  }) : createdAt = createdAt ?? DateTime.now();
}

class Attachment {
  final String fileId;
  final String filename;
  final String mimeType;
  // Semantic kind from the server. One of: plotly, editable, image, file.
  // Null on older rows — fall back to mime_type inference in that case.
  final String? kind;
  final String url;
  final int? sizeBytes;

  const Attachment({
    required this.fileId,
    required this.filename,
    required this.mimeType,
    this.kind,
    required this.url,
    this.sizeBytes,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      fileId: (json['file_id'] as String?) ?? '',
      filename: (json['filename'] as String?) ?? 'attachment',
      mimeType: (json['mime_type'] as String?) ?? 'application/octet-stream',
      kind: json['kind'] as String?,
      url: (json['url'] as String?) ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
    );
  }

  bool get isPlotlyJson =>
      kind == 'plotly' || (kind == null && mimeType == 'application/json');
  bool get isEditable => kind == 'editable';
  bool get isImage =>
      kind == 'image' || (kind == null && mimeType.startsWith('image/'));
}

/// In-memory representation of an editable text document delivered via a
/// `kind: "editable"` attachment. The server owns the authoritative version
/// number and pushes changes as git unified diffs via `text_diff` events.
class TextDocument {
  final String fileId;
  final String filename;
  final String mimeType;
  List<String> lines;
  // Server-assigned version number. Only the server increments this.
  int version;

  TextDocument({
    required this.fileId,
    required this.filename,
    required this.mimeType,
    required this.lines,
    this.version = 0,
  });

  String get content => lines.join('\n');

  /// Apply a git unified diff from the server.
  /// Only applied when [fromVersion] matches [version]; returns false otherwise
  /// (version mismatch — wait for an in-flight echo or `document_resync`).
  bool applyDiff(String diffText, {required int fromVersion, required int toVersion}) {
    if (fromVersion != version) return false;
    if (diffText.trim().isNotEmpty) {
      for (final hunk in _parseHunks(diffText).reversed) {
        _applyHunk(hunk);
      }
    }
    version = toVersion;
    return true;
  }

  /// Hard-reset to the server's authoritative copy (sent on conflict via
  /// `document_resync`).
  void resetFromResync(String text, int newVersion) {
    lines = text.split('\n');
    version = newVersion;
  }

  /// Build a full-file replacement git unified diff from [oldText] to
  /// [newText]. Returns an empty string when the content is unchanged.
  static String generateDiff(String filename, String oldText, String newText) {
    if (oldText == newText) return '';
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');
    final buf = StringBuffer()
      ..writeln('diff --git a/$filename b/$filename')
      ..writeln('--- a/$filename')
      ..writeln('+++ b/$filename')
      ..writeln('@@ -1,${oldLines.length} +1,${newLines.length} @@');
    for (final l in oldLines) { buf.writeln('-$l'); }
    for (final l in newLines) { buf.writeln('+$l'); }
    return buf.toString();
  }

  List<_DiffHunk> _parseHunks(String diffText) {
    final hunkRe = RegExp(
      r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',
      multiLine: true,
    );
    final diffLines = diffText.split('\n');
    final hunks = <_DiffHunk>[];
    int i = 0;
    // Skip file-header lines (diff --git, index, ---, +++)
    while (i < diffLines.length && !diffLines[i].startsWith('@@')) { i++; }
    while (i < diffLines.length) {
      final match = hunkRe.firstMatch(diffLines[i]);
      if (match != null) {
        final oldStart = int.parse(match.group(1)!);
        final oldCount = int.tryParse(match.group(2) ?? '') ?? 1;
        final hunkLines = <String>[];
        i++;
        while (i < diffLines.length && !diffLines[i].startsWith('@@')) {
          hunkLines.add(diffLines[i]);
          i++;
        }
        hunks.add(_DiffHunk(oldStart: oldStart, oldCount: oldCount, lines: hunkLines));
      } else {
        i++;
      }
    }
    return hunks;
  }

  void _applyHunk(_DiffHunk hunk) {
    // @@ -0,0 ... means inserting into empty file → startIdx = 0
    final startIdx = hunk.oldStart == 0 ? 0 : (hunk.oldStart - 1).clamp(0, lines.length);
    final endIdx = (startIdx + hunk.oldCount).clamp(0, lines.length);
    final newLines = <String>[];
    for (final line in hunk.lines) {
      if (line.startsWith('+')) {
        newLines.add(line.substring(1));
      } else if (line.startsWith(' ')) {
        newLines.add(line.substring(1));
      }
      // '-' lines are removed; '\\ No newline...' markers are skipped
    }
    lines.replaceRange(startIdx, endIdx, newLines);
  }
}

class _DiffHunk {
  final int oldStart;
  final int oldCount;
  final List<String> lines;
  const _DiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.lines,
  });
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
  final String? inputMode;
  final DateTime? createdAt;
  final String? preview;

  const ChatSession({
    required this.sessionId,
    this.agentId,
    this.account,
    this.email,
    this.modelId,
    this.status,
    this.inputMode,
    this.createdAt,
    this.preview,
  });

  bool get isStandard => inputMode == null || inputMode == 'standard';

  ChatSession copyWith({
    String? sessionId,
    String? agentId,
    String? account,
    String? email,
    String? modelId,
    String? status,
    String? inputMode,
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
      inputMode: inputMode ?? this.inputMode,
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
      inputMode: json['input_mode'] as String?,
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
