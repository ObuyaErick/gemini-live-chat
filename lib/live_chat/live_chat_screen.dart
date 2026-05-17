import 'dart:convert';

import 'package:file_picker/file_picker.dart';
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
    'csv', 'txt', 'json', 'pdf', 'xlsx',
    'png', 'jpg', 'jpeg', 'gif', 'webp',
  ];

  @override
  void initState() {
    super.initState();
    _agents = agentModels;
    _selectedAgent = _agents.cast<Agent?>().firstWhere(
      (a) => a?.agentId == 'concierge',
      orElse: () => _agents.isNotEmpty ? _agents.first : null,
    );
    _agentId = _selectedAgent?.agentId ?? 'concierge';
    _inputController = TextEditingController(
      // text: _defaultPromptFor(_selectedAgent),
    );
    _provider.loadSessions(_agentId);
    _connect();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _inputController.dispose();
    _scrollController.dispose();
    _provider.dispose();
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
            'eyJhbGciOiJSUzI1NiIsImtpZCI6ImY4ZTY2MjBkMzk3MTFhYTIxY2U4YTJiZjJmM2VlMDFiOTI0Y2IyZDAiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiIzNzQzNjg4ODE5OTQtNjMyMTkxdnY2YTMwcDc1YmRlaTdhdDY0ZTJodnA5OWkuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiIzNzQzNjg4ODE5OTQtNjMyMTkxdnY2YTMwcDc1YmRlaTdhdDY0ZTJodnA5OWkuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDI2MTg1MjYzMjAwMzg0NjEyNTIiLCJoZCI6InJlZHV6ZXIudGVjaCIsImVtYWlsIjoiZmVpc2FsQHJlZHV6ZXIudGVjaCIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJub25jZSI6Im51bGwiLCJuYmYiOjE3Nzg4MzA5NTgsIm5hbWUiOiJGZWlzYWwgTWlnbyIsInBpY3R1cmUiOiJodHRwczovL2xoMy5nb29nbGV1c2VyY29udGVudC5jb20vYS9BQ2c4b2NKY1NleW9lVlg0dTh6QnFTNm1VSURtTlI3blp0all4Si1XZzBRVDNFdHQ2NzFvX1E9czk2LWMiLCJnaXZlbl9uYW1lIjoiRmVpc2FsIiwiZmFtaWx5X25hbWUiOiJNaWdvIiwiaWF0IjoxNzc4ODMxMjU4LCJleHAiOjE3Nzg4MzQ4NTgsImp0aSI6ImU2OTFmNDM4ZDAyOTYxZDYyYzcxMWU5MWZiZjlhNjJhYWM4M2Q4NDQifQ.f3-NcwGCQO5ej_fJQftTYVS0WH-LKTLr02Ohvxsx0CCMD8Q2S4g6uS2SOMNoBAC1lL-HLpAut7Lsp3P_gD8FzuOKoN2hCIx8A0OHJue0pmrGqsp5ek7srFq1xVWzF_2wIgrqJR5Y4YOW9KVIX4OW_80I7akUxehYmCIYt3QYrVxVFLbBsD662mY6IudVSaTmb5ikl9XqNu11f-rm0MMTU7AeMYyWgTJYceAh-IooRi2fxMhZEUnwRMf0ADKkV710siZm9ERrpRBXlhxE_StWojQxIS1XIKEQQOQQtW1kI6PqaSKCE0kYBoFo7SWlJPUd6FBajuUHOaEuGOy97S9L-Q',
        'token':
            'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJlcmlja0ByZWR1emVyLnRlY2giLCJzY29wZSI6ImFkbWluIiwicHJvamVjdCI6Indpbi1wLW1vYmlsZXVuaXZlcnNlIiwiYWNjb3VudCI6Im1vYmlsZV91bml2ZXJzZV9hcGkiLCJkcml2ZUlkIjoiMEFQSnJac1JFbWxPOVVrOVBWQSIsImlzcyI6Im9yZ2FuaXphdGlvbkBib3hhbGluby5jb20iLCJqdGkiOiIyYzNmN2IzOWMwZDBmZDIzN2FlYWI2ZDk4YjUyNjQyYTZiNzI5NjNkIiwiZXhwIjoxNzc4NTQ0MzcxLCJjcmVhdGVkIjoiMjAyNi0wNS0xMSAxNDowNjoyMSJ9.C_XiTzgVMDEQJFfotP0m4BDB5SGEu18D2SlZtEBqVsk',
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
    setState(() {
      _isConnected = false;
      _isWaitingForResponse = false;
      _isInLiveMode = false;
      _streamingMessage = null;
      _pendingAction = null;
      _activeToolEvents.clear();
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
              entries.whereType<Map>().map((raw) {
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
        setState(() {
          _isInLiveMode = mode == 'live';
          if (mode == 'standard') _isWaitingForResponse = false;
        });

      case 'audio_output':
        // Base64 PCM audio from the model (format in payload['mime_type']).
        // Playback requires a native audio package; wire payload['content']
        // into an AudioPlayer when one is available.
        break;

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
        // Model finished its live-mode speech turn. No state change needed —
        // live mode is continuous until the user sends end_live.
        break;

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
            {'filename': f.filename, 'mime_type': f.mimeType, 'data': f.base64Data},
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
    if (channel == null || !_isConnected || _isInLiveMode || _isWaitingForResponse) return;
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

      final mime =
          lookupMimeType(file.name) ??
          'application/octet-stream';
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

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final agentName = _selectedAgent?.agentName ?? 'Agent';
    final agentShortName = _shortAgentName(_selectedAgent);
    final agentSubtitle = _selectedAgent?.agentSubtitle;
    final now = DateTime.now();

    Expanded makeChatArea() => Expanded(
      child: Column(
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
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
                                          _inputController.text =
                                              q.questionText;
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
      ),
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
          body: Row(children: [makeChatArea()]),
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
              makeChatArea(),
            ],
          ),
        ),
      ),
    );
  }
}
