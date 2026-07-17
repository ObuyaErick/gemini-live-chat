import 'dart:convert';
import 'dart:typed_data';

import 'package:webs/live_chat/models/attachment.dart';

enum MessageRole { user, assistant }

enum MessageStatus { streaming, complete, error }

/// A file the user staged locally (via the attach button) to send with the
/// next message. Encoded to base64 on the wire.
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

/// A single chat bubble in the transcript — a user turn, a model turn, or a
/// live-mode transcript line.
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

  /// Which agent produced this message (shared-session threads, v12 §6.7).
  final String? agentId;

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
    this.agentId,
  }) : createdAt = createdAt ?? DateTime.now();
}
