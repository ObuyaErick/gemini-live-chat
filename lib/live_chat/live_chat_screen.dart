import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webs/agents/agents.dart';
import 'package:webs/api/api_client.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';
import 'package:webs/live_chat/widgets/action_confirmation_card.dart';
import 'package:webs/live_chat/widgets/document_editor_panel.dart';
import 'package:webs/live_chat/widgets/date_pill.dart';
import 'package:webs/live_chat/widgets/empty_state.dart';
import 'package:webs/live_chat/widgets/error_banner.dart';
import 'package:webs/live_chat/widgets/input_bar.dart';
import 'package:webs/live_chat/widgets/live_chat_appbar.dart';
import 'package:webs/live_chat/widgets/message_bubble.dart';
import 'package:webs/live_chat/widgets/sessions_sidebar.dart';
import 'package:webs/live_chat/widgets/tool_call_chip.dart';
import 'package:webs/models/agent_models.dart';
import 'package:webs/ui/core/horizontal_layout_breakpoints.dart';

class LiveChat extends StatefulWidget {
  final ChatContext? chatContext;

  const LiveChat({super.key, this.chatContext});

  @override
  State<LiveChat> createState() => _LiveChatState();
}

class _LiveChatState extends State<LiveChat> {
  WebSocketChannel? _channel;
  final List<ChatMessage> _messages = [];
  final List<ToolEvent> _activeToolEvents = [];
  late final TextEditingController _inputController;
  final ScrollController _scrollController = ScrollController();
  final LiveChatProvider _provider = LiveChatProvider();
  bool _isConnected = false;
  bool _isWaitingForResponse = false;
  String? _connectionError;
  late final List<Agent> _agents;
  Agent? _selectedAgent;
  late String _agentId;
  bool _isSidebarOpen = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<SuggestedQuestion> get suggestedQuestions =>
      _selectedAgent?.suggestedQuestions ?? [];

  // The in-progress assistant message being built from delta chunks
  ChatMessage? _streamingMessage;

  // An action tool call awaiting user confirm/cancel. Mirrors the server-side
  // `_PendingAction` on ChatHandler: while set, the turn is parked until we
  // send back `action_confirm` or `action_cancel`.
  PendingAction? _pendingAction;

  // Files staged by the user via the attach button, sent with the next message.
  final List<LocalFileAttachment> _stagedFiles = [];

  // Whether the connection is currently in live (voice) mode.
  bool _isInLiveMode = false;

  // Editable documents opened by the agent (kind: "editable" attachments).
  // Keyed by file_id; updated in-place when text_diff ops arrive.
  final Map<String, TextDocument> _openDocuments = {};
  String? _activeDocumentFileId;

  // Audio player for live-mode output.
  AudioPlayer? _audioPlayer;

  // PCM bytes accumulating during the current live-mode turn. Flushed and
  // played when turn_complete arrives.
  final List<int> _pendingAudioBytes = [];
  int _liveAudioSampleRate = 16000;

  static const _allowedMimeTypes = {
    'text/csv',
    'text/plain',
    'application/json',
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'image/png',
    'image/jpeg',
    'image/gif',
    'image/webp',
  };

  static const _allowedExtensions = [
    'csv',
    'txt',
    'json',
    'pdf',
    'xlsx',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
  ];

  @override
  void initState() {
    super.initState();
    _agents = agentModels;
    _selectedAgent = _agents.cast<Agent?>().firstWhere(
      (a) => a?.agentId == 'bob_the_kpi_guy',
      orElse: () => _agents.isNotEmpty ? _agents.first : null,
    );
    _agentId = _selectedAgent?.agentId ?? 'concierge';
    _inputController = TextEditingController(
      // text: _defaultPromptFor(_selectedAgent),
    );
    _provider.loadSessions(_agentId);
    _audioPlayer = AudioPlayer();
    _connect();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _inputController.dispose();
    _scrollController.dispose();
    _provider.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  // String _defaultPromptFor(Agent? agent) {
  //   if (agent == null) return '';
  //   if (agent.suggestedQuestions.isNotEmpty) {
  //     final sorted = [...agent.suggestedQuestions]
  //       ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  //     return sorted.first.questionText;
  //   }
  //   return agent.agentWelcomeMessage ?? '';
  // }

  String _shortAgentName(Agent? agent) {
    final name = agent?.agentName.trim();
    if (name == null || name.isEmpty) return 'Agent';
    final first = name.split(RegExp(r'\s+')).first;
    return first.isEmpty ? name : first;
  }

  void _switchAgent(Agent agent) {
    if (_selectedAgent?.agentId == agent.agentId) return;

    setState(() {
      _selectedAgent = agent;
      _agentId = agent.agentId;
      _messages.clear();
      _activeToolEvents.clear();
      _streamingMessage = null;
      _pendingAction = null;
      _isWaitingForResponse = false;
      _isInLiveMode = false;
      _connectionError = null;
      _inputController.text = '';
      _openDocuments.clear();
      _activeDocumentFileId = null;
    });
    _provider.clearCurrentSession();
    _provider.loadSessions(agent.agentId);

    _disconnect();
    _connect();
  }

  void _selectSession(ChatSession session) {
    if (_provider.currentSessionId == session.sessionId) return;

    setState(() {
      _messages.clear();
      _activeToolEvents.clear();
      _streamingMessage = null;
      _pendingAction = null;
      _isWaitingForResponse = false;
      _isInLiveMode = false;
      _connectionError = null;
      _openDocuments.clear();
      _activeDocumentFileId = null;
    });
    _provider.selectSession(session.sessionId);

    _disconnect();
    _connect();
  }

  void _newSession() {
    setState(() {
      _messages.clear();
      _activeToolEvents.clear();
      _streamingMessage = null;
      _pendingAction = null;
      _isWaitingForResponse = false;
      _isInLiveMode = false;
      _connectionError = null;
      _openDocuments.clear();
      _activeDocumentFileId = null;
    });
    _provider.clearCurrentSession();

    _disconnect();
    _connect();
  }

  void _toggleSidebar() {
    setState(() => _isSidebarOpen = !_isSidebarOpen);
  }

  // ------------------------------------------------------------------
  // Connection
  // ------------------------------------------------------------------

  Future<void> _connect() async {
    setState(() {
      _connectionError = null;
      _isConnected = false;
    });

    try {
      final params = {
        'session_id': ?_provider.currentSessionId,
        // 'token': ?ApiClient.token,
        'go_auth_token':
            'eyJhbGciOiJSUzI1NiIsImtpZCI6ImYzNjE5MTM3MWM4YzRmZmQxNjI4NDZjZGU5MWE5Y2I0YzJiZWJhZTIiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiIzNzQzNjg4ODE5OTQtNjMyMTkxdnY2YTMwcDc1YmRlaTdhdDY0ZTJodnA5OWkuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiIzNzQzNjg4ODE5OTQtNjMyMTkxdnY2YTMwcDc1YmRlaTdhdDY0ZTJodnA5OWkuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMTM4MTc5NTA1MzcwMTA5MjM4MzgiLCJoZCI6InJlZHV6ZXIudGVjaCIsImVtYWlsIjoiZXJpY2tAcmVkdXplci50ZWNoIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsIm5vbmNlIjoibm90X3Byb3ZpZGVkIiwibmJmIjoxNzgyODkyOTIxLCJuYW1lIjoiRXJpY2sgT2J1eWEiLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDMuZ29vZ2xldXNlcmNvbnRlbnQuY29tL2EvQUNnOG9jTHA4bm5HaVQzaWV6MVFmYlBrWHRtcjlFWGxwekFqSFJQdUNoTWtJNnNlRFItZ3ZqTT1zOTYtYyIsImdpdmVuX25hbWUiOiJFcmljayIsImZhbWlseV9uYW1lIjoiT2J1eWEiLCJpYXQiOjE3ODI4OTMyMjEsImV4cCI6MTc4Mjg5NjgyMSwianRpIjoiNWZhOWU3NmNlZjE1MmIxNDk4NzNlNjBlZDJlOGMzZTU3MmZiOTk5ZiJ9.SxWyPsb8X3mHlHSzu0FdSPUJybF1YUrFZuZDoAfuXAB7HtskQpF-OeBeKUsIklkm9fXPpF76p5_YSYJv-YBQlNfld8ce2lukCeX4yspirKQE5zmZHgu41dEAGtUK2BbTLulu_qzC32eHNPZ8NX3JoshMWEaQaU-skofDiHHSmzruxl8y7spt3GiEhe2Ia40brtaT-1_-MqYAy6N-gi33DEJgTE_yP1F5Ow1CMhzE3XaGLZ2QyLZOzkxo5OkClZT-rWhqpx9X4VuZf6I6vZAT3BbL79U20G5YEbTET-kRjnHJWtdELBnxvFuT7UUaf8Tw1a_9-BN315M-XHGHGSru1A',
        'token':
            'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJlcmlja0ByZWR1emVyLnRlY2giLCJzY29wZSI6ImFkbWluIiwicHJvamVjdCI6Indpbi1wLW1vYmlsZXVuaXZlcnNlIiwiYWNjb3VudCI6Im1vYmlsZV91bml2ZXJzZV9hcGkiLCJkcml2ZUlkIjoiMEFQSnJac1JFbWxPOVVrOVBWQSIsImlzcyI6Im9yZ2FuaXphdGlvbkBib3hhbGluby5jb20iLCJqdGkiOiI1ZmE5ZTc2Y2VmMTUyYjE0OTg3M2U2MGVkMmU4YzNlNTcyZmI5OTlmIiwiZXhwIjoxNzgyOTM2NDIxLCJjcmVhdGVkIjoiMjAyNi0wNy0wMSAxMDowNzo1MSJ9.XIv_qCj1OmVaNBfwlNH9Dl4O-zRS0YxxJi4m-jZ57U8',
      };
      _channel = WebSocketChannel.connect(
        Uri.parse(
          '${ApiClient.baseWebsocketUrl}/chat/$_agentId?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}',
        ),
      );
      final channel = _channel!;
      channel.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      setState(() => _isConnected = true);

      await channel.ready;
      if (!mounted || _channel != channel) return;
      _pushContextIfApplicable(channel);
    } catch (e) {
      if (!mounted) return;
      setState(() => _connectionError = 'Connection failed: $e');
    }
  }

  void _pushContextIfApplicable(WebSocketChannel channel) {
    final ctx = widget.chatContext;
    if (ctx == null) return;
    if (_selectedAgent?.agentId != 'concierge') return;
    try {
      channel.sink.add(jsonEncode({'context': ctx.toJson()}));
    } catch (_) {
      // Non-fatal: surface via the regular error path if the socket is broken.
    }
  }

  void _disconnect() {
    _channel?.sink.close();
    _pendingAudioBytes.clear();
    _audioPlayer?.stop();
    setState(() {
      _isConnected = false;
      _isWaitingForResponse = false;
      _isInLiveMode = false;
      _streamingMessage = null;
      _pendingAction = null;
      _activeToolEvents.clear();
      _openDocuments.clear();
      _activeDocumentFileId = null;
    });
  }

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = dt.hour;
    final m = two(dt.minute);
    final hour12 = ((h + 11) % 12) + 1;
    final ampm = h >= 12 ? 'PM' : 'AM';
    return '$hour12:$m $ampm';
  }

  String _formatTodayPill(DateTime dt) => 'TODAY, ${_formatTime(dt)}';

  List<Attachment> _parseAttachments(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Attachment.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  // ------------------------------------------------------------------
  // WebSocket event handlers
  // ------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw as String);
      debugPrint("--------\n${jsonEncode(payload)}");
    } catch (_) {
      return; // malformed frame — ignore
    }

    final type = payload['type'] as String?;

    if (type == 'final' && _messages.length <= 2) {
      final userMessage = _messages.first.content;
      _provider.updateCurrentSessionPreview(userMessage);
    }

    switch (type) {
      case 'session':
        final content = (payload['content'] as Map?)?.cast<String, dynamic>();

        if (content == null) return;
        _provider.registerSessionFromServer(content);

      case 'history':
        final content =
            (payload['content'] as Map?)?.cast<String, dynamic>() ?? const {};
        final historyAgentId = content['agent_id'] as String?;
        if (historyAgentId != null && historyAgentId != _agentId) {
          // Stale frame from a previous agent connection — ignore.
          return;
        }
        final entries = (content['data'] as List?) ?? const [];
        setState(() {
          _messages
            ..clear()
            ..addAll(
              // role: "edit" entries are document diffs, not chat bubbles — skip.
              entries.whereType<Map>().where((raw) {
                final role = raw['role'] as String?;
                return role == 'user' || role == 'model';
              }).map((raw) {
                final e = raw.cast<String, dynamic>();
                final role = (e['role'] as String?) ?? 'assistant';
                return ChatMessage(
                  role: role == 'user'
                      ? MessageRole.user
                      : MessageRole.assistant,
                  content: (e['text'] as String?) ?? '',
                  status: MessageStatus.complete,
                  attachments: _parseAttachments(e['attachments']),
                );
              }),
            );
          _streamingMessage = null;
          _activeToolEvents.clear();
          _pendingAction = null;
          _isWaitingForResponse = false;
        });
        _scrollToBottom();
        // Build edit index: file_id → chronological list of role:"edit" entries.
        final editsByFileId = <String, List<Map<String, dynamic>>>{};
        for (final raw in entries.whereType<Map>()) {
          final e = raw.cast<String, dynamic>();
          if ((e['role'] as String?) == 'edit') {
            final fileId = e['file_id'] as String?;
            if (fileId != null) {
              editsByFileId.putIfAbsent(fileId, () => []).add(e);
            }
          }
        }
        // Open editable attachments, replaying their edit history on top.
        final seen = <String>{};
        for (final raw in entries.whereType<Map>()) {
          final e = raw.cast<String, dynamic>();
          if ((e['role'] as String?) != 'model') continue;
          for (final att in _parseAttachments(e['attachments']).where((a) => a.isEditable)) {
            if (seen.add(att.fileId)) {
              _fetchAndOpenDocument(att, edits: editsByFileId[att.fileId] ?? const []);
            }
          }
        }

      case 'tool_call':
        final callContent =
            (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        setState(() {
          _activeToolEvents.add(
            ToolEvent(
              name: callContent['name'] as String,
              args: (callContent['args'] as Map?)?.cast<String, dynamic>(),
            ),
          );
        });

      case 'tool_result':
        final resultContent =
            (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        setState(() {
          final name = resultContent['name'] as String;
          final idx = _activeToolEvents.indexWhere(
            (e) => e.name == name && e.result == null,
          );
          if (idx != -1) {
            final toolResult = (resultContent['result'] as Map?)
                ?.cast<String, dynamic>();
            final old = _activeToolEvents[idx];
            _activeToolEvents[idx] = ToolEvent(
              name: old.name,
              args: old.args,
              result: toolResult,
            );
          }
        });

      case 'action_confirmation':
        final content =
            (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        setState(() {
          _pendingAction = PendingAction(
            toolName: (content['tool_name'] as String?) ?? 'action',
            summary: (content['summary'] as String?) ?? 'Confirm action?',
            parameters:
                (content['parameters'] as Map?)?.cast<String, dynamic>() ??
                const {},
          );
        });
        _scrollToBottom();

      case 'navigate':
        final nav = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final target = nav['target'] as String?;
        if (target == null || target.isEmpty) return;
        final params = (nav['params'] as Map?)?.cast<String, dynamic>();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                params == null || params.isEmpty
                    ? 'Navigate → $target'
                    : 'Navigate → $target  •  $params',
              ),
              duration: const Duration(seconds: 10),
            ),
          );
        }

      case 'delta':
        final chunk = payload['content'] as String? ?? '';
        if (chunk.isEmpty) return;

        setState(() {
          if (_streamingMessage == null) {
            _streamingMessage = ChatMessage(
              role: MessageRole.assistant,
              content: chunk,
              status: MessageStatus.streaming,
            );
            _messages.add(_streamingMessage!);
          } else {
            _streamingMessage!.content += chunk;
          }
        });
        _scrollToBottom();

      case 'final':
        final attachments = _parseAttachments(payload['attachments']);
        setState(() {
          if (_streamingMessage != null) {
            _streamingMessage!.status = MessageStatus.complete;
            if (attachments.isNotEmpty) {
              _streamingMessage!.attachments = attachments;
            }
            _streamingMessage = null;
          } else {
            final content = payload['content'] as String? ?? '';
            if (content.isNotEmpty) {
              _messages.add(
                ChatMessage(
                  role: MessageRole.assistant,
                  content: content,
                  status: MessageStatus.complete,
                  attachments: attachments,
                ),
              );
            }
          }
          _activeToolEvents.clear();
          _isWaitingForResponse = false;
        });
        // Open any editable documents delivered in this turn.
        for (final att in attachments.where((a) => a.isEditable)) {
          _fetchAndOpenDocument(att);
        }
        _scrollToBottom();

      case 'image':
        final imageContent =
            (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final data = imageContent['data'] as String? ?? '';
        final mimeType = imageContent['mime_type'] as String? ?? 'image/png';
        if (data.isEmpty) return;
        setState(() {
          _messages.add(
            ChatMessage(
              role: MessageRole.assistant,
              status: MessageStatus.complete,
              imageBytes: base64Decode(data),
              imageMimeType: mimeType,
            ),
          );
        });
        _scrollToBottom();

      case 'context_ack':
        final ack = (payload['content'] as Map?)?.cast<String, dynamic>();
        final label = ack?['title'] ?? ack?['page'] ?? ack?['module'];
        final text = label == null
            ? 'Context acknowledged'
            : 'Context acknowledged: $label';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(text),
              duration: const Duration(seconds: 20),
              action: SnackBarAction(
                label: 'Dismiss',
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }

      case 'mode_changed':
        final modeContent =
            (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final mode = modeContent['mode'] as String?;
        if (mode == 'standard' && _pendingAudioBytes.isNotEmpty) {
          _playPcmAudio(
            Uint8List.fromList(_pendingAudioBytes),
            _liveAudioSampleRate,
          );
          _pendingAudioBytes.clear();
        } else if (mode != 'live') {
          _pendingAudioBytes.clear();
        }
        setState(() {
          _isInLiveMode = mode == 'live';
          if (mode == 'standard') _isWaitingForResponse = false;
        });

      case 'audio_output':
        final b64 = payload['content'] as String? ?? '';
        final mimeType = payload['mime_type'] as String? ?? '';
        if (b64.isEmpty) break;
        _liveAudioSampleRate = _parseSampleRate(mimeType);
        _pendingAudioBytes.addAll(base64Decode(b64));

      case 'output_transcript':
        final text = payload['content'] as String? ?? '';
        if (text.isEmpty) return;
        setState(() {
          _messages.add(
            ChatMessage(
              role: MessageRole.assistant,
              content: text,
              status: MessageStatus.complete,
              isTranscript: true,
            ),
          );
        });
        _scrollToBottom();

      case 'input_transcript':
        final text = payload['content'] as String? ?? '';
        if (text.isEmpty) return;
        setState(() {
          _messages.add(
            ChatMessage(
              role: MessageRole.user,
              content: text,
              isTranscript: true,
            ),
          );
        });
        _scrollToBottom();

      case 'turn_complete':
        if (_pendingAudioBytes.isNotEmpty) {
          _playPcmAudio(
            Uint8List.fromList(_pendingAudioBytes),
            _liveAudioSampleRate,
          );
          _pendingAudioBytes.clear();
        }

      case 'executable_code':
      case 'code_execution_result':
        // Informational frames — the model's native code execution.
        // The human-facing answer always follows in delta/final; drop silently.
        break;

      case 'text_diff':
        final diffContent =
            (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final diffFileId = diffContent['file_id'] as String?;
        final fromVersion = (diffContent['from_version'] as num?)?.toInt() ?? 0;
        final toVersion = (diffContent['to_version'] as num?)?.toInt() ?? 0;
        final diffText = diffContent['diff'] as String? ?? '';
        if (diffFileId == null) break;
        final targetDoc = _openDocuments[diffFileId];
        if (targetDoc == null) break;
        setState(() {
          if (targetDoc.applyDiff(
            diffText,
            fromVersion: fromVersion,
            toVersion: toVersion,
          )) {
            _activeDocumentFileId = diffFileId;
          }
        });

      case 'document_resync':
        final resyncContent =
            (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final resyncFileId = resyncContent['file_id'] as String?;
        final resyncVersion = (resyncContent['version'] as num?)?.toInt() ?? 0;
        final resyncText = resyncContent['text'] as String? ?? '';
        if (resyncFileId == null) break;
        setState(() {
          if (_openDocuments.containsKey(resyncFileId)) {
            _openDocuments[resyncFileId]!
                .resetFromResync(resyncText, resyncVersion);
          } else {
            _openDocuments[resyncFileId] = TextDocument(
              fileId: resyncFileId,
              filename: (resyncContent['filename'] as String?) ?? resyncFileId,
              mimeType:
                  (resyncContent['mime_type'] as String?) ?? 'text/plain',
              lines: resyncText.split('\n'),
              version: resyncVersion,
            );
            _activeDocumentFileId ??= resyncFileId;
          }
        });

      case 'error':
        final errMsg = payload['content'] as String? ?? 'Unknown error';
        setState(() {
          _streamingMessage?.status = MessageStatus.error;
          _streamingMessage = null;
          _activeToolEvents.clear();
          _pendingAction = null;
          _isWaitingForResponse = false;
          _isInLiveMode = false;
          _messages.add(
            ChatMessage(
              role: MessageRole.assistant,
              content: errMsg,
              status: MessageStatus.error,
            ),
          );
        });
        _scrollToBottom();
    }
  }

  void _onError(Object error) {
    _pendingAudioBytes.clear();
    _audioPlayer?.stop();
    setState(() {
      _isConnected = false;
      _isWaitingForResponse = false;
      _isInLiveMode = false;
      _connectionError = 'WebSocket error: $error';
      _streamingMessage = null;
      _activeToolEvents.clear();
    });
  }

  void _onDone() {
    _pendingAudioBytes.clear();
    setState(() {
      _isConnected = false;
      _isWaitingForResponse = false;
      _isInLiveMode = false;
      _streamingMessage = null;
      _activeToolEvents.clear();
    });
  }

  // ------------------------------------------------------------------
  // Send
  // ------------------------------------------------------------------

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty || !_isConnected || _isWaitingForResponse) return;

    final files = _stagedFiles.toList();

    setState(() {
      _messages.add(
        ChatMessage(
          role: MessageRole.user,
          content: text,
          localAttachments: files,
        ),
      );
      _isWaitingForResponse = true;
      _stagedFiles.clear();
    });

    _inputController.clear();
    _scrollToBottom();

    try {
      final payload = <String, dynamic>{'text': text};
      if (files.isNotEmpty) {
        payload['attachments'] = [
          for (final f in files)
            {
              'filename': f.filename,
              'mime_type': f.mimeType,
              'data': f.base64Data,
            },
        ];
      }
      _channel!.sink.add(jsonEncode(payload));
    } catch (e) {
      setState(() {
        _isWaitingForResponse = false;
        _messages.add(
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Failed to send: $e',
            status: MessageStatus.error,
          ),
        );
      });
    }
  }

  void _confirmAction() {
    final pending = _pendingAction;
    if (pending == null) return;
    _sendActionDecision(pending.toolName, confirmed: true);
  }

  void _cancelAction() {
    final pending = _pendingAction;
    if (pending == null) return;
    _sendActionDecision(pending.toolName, confirmed: false);
  }

  void _sendActionDecision(String toolName, {required bool confirmed}) {
    final channel = _channel;
    if (channel == null || !_isConnected) return;

    setState(() => _pendingAction = null);

    try {
      channel.sink.add(
        jsonEncode({
          'type': confirmed ? 'action_confirm' : 'action_cancel',
          'tool_name': toolName,
        }),
      );
    } catch (e) {
      setState(() {
        _isWaitingForResponse = false;
        _messages.add(
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Failed to send action decision: $e',
            status: MessageStatus.error,
          ),
        );
      });
    }
  }

  void _startLiveMode() {
    final channel = _channel;
    if (channel == null ||
        !_isConnected ||
        _isInLiveMode ||
        _isWaitingForResponse) {
      return;
    }
    try {
      channel.sink.add(jsonEncode({'type': 'start_live'}));
    } catch (_) {}
  }

  void _endLiveMode() {
    final channel = _channel;
    if (channel == null || !_isConnected || !_isInLiveMode) return;
    try {
      channel.sink.add(jsonEncode({'end_live': true}));
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // Document helpers
  // ------------------------------------------------------------------

  void _sendDocumentEdit(String fileId, String diff) {
    final channel = _channel;
    if (channel == null || !_isConnected || diff.isEmpty) return;
    try {
      channel.sink.add(jsonEncode({
        'type': 'document_edit',
        'content': {'file_id': fileId, 'diff': diff},
      }));
    } catch (_) {}
  }

  Future<void> _fetchAndOpenDocument(
    Attachment att, {
    List<Map<String, dynamic>> edits = const [],
  }) async {
    if (att.url.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(att.url));
      if (mounted) {
        if (response.statusCode == 200) {
          final doc = TextDocument(
            fileId: att.fileId,
            filename: att.filename,
            mimeType: att.mimeType,
            lines: response.body.split('\n'),
          );
          // Replay only edits that belong to this document.
          for (final edit in edits) {
            if ((edit['file_id'] as String?) != att.fileId) continue;
            final fromVersion = (edit['from_version'] as num?)?.toInt() ?? 0;
            final toVersion = (edit['to_version'] as num?)?.toInt() ?? 0;
            final diff = edit['diff'] as String? ?? '';
            doc.applyDiff(diff, fromVersion: fromVersion, toVersion: toVersion);
          }
          setState(() {
            _openDocuments[att.fileId] = doc;
            _activeDocumentFileId ??= att.fileId;
          });
        } else {
          debugPrint('[doc-fetch] ${att.filename}: HTTP ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('[doc-fetch] ${att.filename}: $e');
    }
  }

  // ------------------------------------------------------------------
  // Audio helpers (live mode)
  // ------------------------------------------------------------------

  static int _parseSampleRate(String mimeType) {
    final m = RegExp(r'rate=(\d+)').firstMatch(mimeType);
    return m != null ? (int.tryParse(m.group(1)!) ?? 16000) : 16000;
  }

  // Wraps raw PCM s16le bytes in a minimal WAV container so just_audio can
  // decode it without any native codec support.
  static Uint8List _buildWav(Uint8List pcm, {int sampleRate = 16000}) {
    const numChannels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = pcm.length;

    final hdr = ByteData(44);
    // RIFF chunk
    hdr
      ..setUint8(0, 0x52)
      ..setUint8(1, 0x49)
      ..setUint8(2, 0x46)
      ..setUint8(3, 0x46)
      ..setUint32(4, 36 + dataSize, Endian.little)
      ..setUint8(8, 0x57)
      ..setUint8(9, 0x41)
      ..setUint8(10, 0x56)
      ..setUint8(11, 0x45)
      // fmt  sub-chunk
      ..setUint8(12, 0x66)
      ..setUint8(13, 0x6D)
      ..setUint8(14, 0x74)
      ..setUint8(15, 0x20)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, numChannels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little)
      // data sub-chunk
      ..setUint8(36, 0x64)
      ..setUint8(37, 0x61)
      ..setUint8(38, 0x74)
      ..setUint8(39, 0x61)
      ..setUint32(40, dataSize, Endian.little);

    final out = Uint8List(44 + dataSize);
    out.setAll(0, hdr.buffer.asUint8List());
    out.setAll(44, pcm);
    return out;
  }

  Future<void> _playPcmAudio(Uint8List pcm, int sampleRate) async {
    final player = _audioPlayer;
    if (player == null || pcm.isEmpty) return;
    final wav = _buildWav(pcm, sampleRate: sampleRate);
    final dataUri = 'data:audio/wav;base64,${base64Encode(wav)}';
    try {
      await player.stop();
      await player.setUrl(dataUri);
      await player.play();
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !mounted) return;

    final errors = <String>[];
    final picked = <LocalFileAttachment>[];

    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;

      if (bytes.length > 20 * 1024 * 1024) {
        errors.add(
          '${file.name} is ${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB; maximum is 20 MB',
        );
        continue;
      }

      final mime = lookupMimeType(file.name) ?? 'application/octet-stream';
      if (!_allowedMimeTypes.contains(mime)) {
        errors.add('${file.name}: unsupported type "$mime"');
        continue;
      }

      picked.add(
        LocalFileAttachment(filename: file.name, mimeType: mime, bytes: bytes),
      );
    }

    setState(() => _stagedFiles.addAll(picked));

    if (errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join('\n')),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _removeStagedFile(LocalFileAttachment file) {
    setState(() => _stagedFiles.remove(file));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 200,
      ),
    );
  }

  Widget _makeEditorPanel() => SizedBox(
    width: 440,
    child: DocumentEditorPanel(
      documents: _openDocuments,
      activeFileId: _activeDocumentFileId,
      onSelectDocument: (id) => setState(() => _activeDocumentFileId = id),
      onClose: (id) => setState(() {
        _openDocuments.remove(id);
        if (_activeDocumentFileId == id) {
          _activeDocumentFileId = _openDocuments.keys.firstOrNull;
        }
      }),
      onUserEdit: _sendDocumentEdit,
    ),
  );

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final agentName = _selectedAgent?.agentName ?? 'Agent';
    final agentShortName = _shortAgentName(_selectedAgent);
    final agentSubtitle = _selectedAgent?.agentSubtitle;
    final now = DateTime.now();

    Widget makeChatArea() => Column(
      children: [
        if (_connectionError != null)
          ErrorBanner(message: _connectionError!, onRetry: _connect),
        Expanded(
          child: Stack(
            children: [
              _messages.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 48,
                      ),
                      child: EmptyState(
                        agentName: agentName,
                        subtitle: agentSubtitle,
                        actions: [
                          ...suggestedQuestions.expand(
                            (q) => [
                              SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Row(
                                  spacing: 8,

                                  children: [
                                    Expanded(
                                      child: Text(
                                        q.questionText,
                                        softWrap: true,
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () =>
                                          copyToClipboard(q.questionText),
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                      ),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () {
                                        _inputController.text = q.questionText;
                                        _sendMessage();
                                      },
                                      icon: const Icon(
                                        Icons
                                            .keyboard_double_arrow_right_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => MessageBubble(
                        message: _messages[i],
                        agentName: agentName,
                        formatTime: _formatTime,
                      ),
                    ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: DatePill(text: _formatTodayPill(now)),
                ),
              ),
            ],
          ),
        ),
        if (_activeToolEvents.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: ToolCallChip(events: _activeToolEvents),
          ),
        if (_pendingAction != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: ActionConfirmationCard(
              action: _pendingAction!,
              onConfirm: _confirmAction,
              onCancel: _cancelAction,
            ),
          ),
        InputBar(
          controller: _inputController,
          enabled: _isConnected && !_isWaitingForResponse,
          isWaiting: _isWaitingForResponse,
          agentShortName: agentShortName,
          onSend: _sendMessage,
          onAttach: _pickFile,
          stagedFiles: _stagedFiles,
          onRemoveStagedFile: _removeStagedFile,
          isInLiveMode: _isInLiveMode,
          onToggleLiveMode: _isConnected
              ? (_isInLiveMode ? _endLiveMode : _startLiveMode)
              : null,
        ),
      ],
    );

    return ChangeNotifierProvider<LiveChatProvider>.value(
      value: _provider,
      child: HorizontalLayoutBreakpoints(
        all: (context, _) => Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF6F7FB),
          drawer: Drawer(
            width: SessionsSidebar.openWidth,
            child: SessionsSidebar(
              onSelectSession: (s) {
                _selectSession(s);
                _scaffoldKey.currentState?.closeDrawer();
              },
              onNewSession: () {
                _newSession();
                _scaffoldKey.currentState?.closeDrawer();
              },
              onEvictAllSessions: () {
                _provider.evictAllSessions();
                _newSession();
                _scaffoldKey.currentState?.closeDrawer();
              },
              onEvictSession: (s) {
                _provider.evictSession(s.sessionId);
                if (_provider.currentSessionId == s.sessionId) {
                  _newSession();
                }
                _scaffoldKey.currentState?.closeDrawer();
              },
              isOpen: true,
              onToggle: () => _scaffoldKey.currentState?.closeDrawer(),
            ),
          ),
          appBar: LiveChatAppBar(
            isConnected: _isConnected,
            agents: _agents,
            selectedAgent: _selectedAgent,
            onSelectAgent: _switchAgent,
            onToggleConnection: _isConnected ? _disconnect : _connect,
            isSidebarOpen: false,
            onToggleSidebar: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          body: Row(
            children: [
              Expanded(flex: 2, child: makeChatArea()),
              if (_openDocuments.isNotEmpty) _makeEditorPanel(),
            ],
          ),
        ),
        md: (context, _) => Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: LiveChatAppBar(
            isConnected: _isConnected,
            agents: _agents,
            selectedAgent: _selectedAgent,
            onSelectAgent: _switchAgent,
            onToggleConnection: _isConnected ? _disconnect : _connect,
            isSidebarOpen: _isSidebarOpen,
            onToggleSidebar: _toggleSidebar,
          ),
          body: Row(
            children: [
              SessionsSidebar(
                onSelectSession: _selectSession,
                onNewSession: _newSession,
                onEvictSession: (s) {
                  _provider.evictSession(s.sessionId);
                  if (_provider.currentSessionId == s.sessionId) {
                    _newSession();
                  }
                  _scaffoldKey.currentState?.closeDrawer();
                },
                onEvictAllSessions: () {
                  _provider.evictAllSessions();
                  _newSession();
                  _scaffoldKey.currentState?.closeDrawer();
                },
                isOpen: _isSidebarOpen,
                onToggle: _toggleSidebar,
              ),
              Expanded(flex: 2, child: makeChatArea()),
              if (_openDocuments.isNotEmpty) _makeEditorPanel(),
            ],
          ),
        ),
      ),
    );
  }
}
