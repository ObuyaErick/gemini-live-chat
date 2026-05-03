import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:webs/live_chat/widgets/message_bubble.dart';
import 'package:webs/live_chat/widgets/sessions_sidebar.dart';
import 'package:webs/live_chat/widgets/tool_call_chip.dart';
import 'package:webs/models/agent_models.dart';

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

  List<SuggestedQuestion> get suggestedQuestions =>
      _selectedAgent?.suggestedQuestions ?? [];

  // The in-progress assistant message being built from delta chunks
  ChatMessage? _streamingMessage;

  // An action tool call awaiting user confirm/cancel. Mirrors the server-side
  // `_PendingAction` on ChatHandler: while set, the turn is parked until we
  // send back `action_confirm` or `action_cancel`.
  PendingAction? _pendingAction;

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

  String _defaultPromptFor(Agent? agent) {
    if (agent == null) return '';
    if (agent.suggestedQuestions.isNotEmpty) {
      final sorted = [...agent.suggestedQuestions]
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return sorted.first.questionText;
    }
    return agent.agentWelcomeMessage ?? '';
  }

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
      _connectionError = null;
      _inputController.text = _defaultPromptFor(agent);
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
        'token': ApiClient.token,
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

  // ------------------------------------------------------------------
  // WebSocket event handlers
  // ------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw as String);
    } catch (_) {
      return; // malformed frame — ignore
    }

    final type = payload['type'] as String?;

    print("Payload: $payload");

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
        setState(() {
          if (_streamingMessage != null) {
            _streamingMessage!.status = MessageStatus.complete;
            _streamingMessage = null;
          } else {
            final content = payload['content'] as String? ?? '';
            if (content.isNotEmpty) {
              _messages.add(
                ChatMessage(
                  role: MessageRole.assistant,
                  content: content,
                  status: MessageStatus.complete,
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

      case 'error':
        final errMsg = payload['content'] as String? ?? 'Unknown error';
        setState(() {
          _streamingMessage?.status = MessageStatus.error;
          _streamingMessage = null;
          _activeToolEvents.clear();
          _pendingAction = null;
          _isWaitingForResponse = false;
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
      _connectionError = 'WebSocket error: $error';
      _streamingMessage = null;
      _activeToolEvents.clear();
    });
  }

  void _onDone() {
    setState(() {
      _isConnected = false;
      _isWaitingForResponse = false;
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

    setState(() {
      _messages.add(ChatMessage(role: MessageRole.user, content: text));
      _isWaitingForResponse = true;
    });

    _inputController.clear();
    _scrollToBottom();

    try {
      _channel!.sink.add(jsonEncode({'text': text}));
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

    return ChangeNotifierProvider<LiveChatProvider>.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: _LiveChatAppBar(
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
              isOpen: _isSidebarOpen,
              onToggle: _toggleSidebar,
            ),
            Expanded(
              child: Column(
                children: [
                  if (_connectionError != null)
                    ErrorBanner(message: _connectionError!, onRetry: _connect),
                  Expanded(
                    child: Stack(
                      children: [
                        _messages.isEmpty
                            ? EmptyState(
                                agentName: agentName,
                                subtitle: agentSubtitle,
                                actions: [
                                  Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        ...suggestedQuestions.map(
                                          (q) => Container(
                                            padding: EdgeInsets.symmetric(
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
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  q.questionText,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),

                                                IconButton(
                                                  constraints: BoxConstraints(),
                                                  padding: EdgeInsets.all(4),
                                                  onPressed: () {
                                                    copyToClipboard(
                                                      q.questionText,
                                                    );
                                                  },
                                                  icon: Icon(
                                                    Icons.copy_rounded,
                                                    size: 18,
                                                  ),
                                                ),

                                                IconButton(
                                                  constraints: BoxConstraints(),
                                                  padding: EdgeInsets.all(4),
                                                  onPressed: () {
                                                    _inputController.text =
                                                        q.questionText;
                                                    _sendMessage();
                                                  },
                                                  icon: Icon(
                                                    Icons
                                                        .keyboard_double_arrow_right_rounded,
                                                    size: 18,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  56,
                                  24,
                                  24,
                                ),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isConnected;
  final List<Agent> agents;
  final Agent? selectedAgent;
  final ValueChanged<Agent> onSelectAgent;
  final VoidCallback onToggleConnection;
  final bool isSidebarOpen;
  final VoidCallback onToggleSidebar;

  const _LiveChatAppBar({
    required this.isConnected,
    required this.agents,
    required this.selectedAgent,
    required this.onSelectAgent,
    required this.onToggleConnection,
    required this.isSidebarOpen,
    required this.onToggleSidebar,
  });

  @override
  Size get preferredSize => const Size.fromHeight(73);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: 72,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      titleSpacing: 4,
      leading: IconButton(
        icon: Icon(
          isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
        ),
        tooltip: isSidebarOpen ? 'Hide sessions' : 'Show sessions',
        onPressed: onToggleSidebar,
      ),
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFD6C9),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<Agent>(
                    value: selectedAgent,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    onChanged: (a) {
                      if (a == null) return;
                      onSelectAgent(a);
                    },
                    items: agents
                        .map(
                          (a) => DropdownMenuItem<Agent>(
                            value: a,
                            child: Text(
                              a.agentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  spacing: 16,
                  children: [
                    Text(
                      isConnected
                          ? 'STATUS: CONNECTED'
                          : 'STATUS: DISCONNECTED',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Consumer<LiveChatProvider>(
                        builder: (context, chatProvider, child) => Text(
                          chatProvider.currentSessionId ?? "",
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.6,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(isConnected ? Icons.link : Icons.link_off),
          tooltip: isConnected ? 'Connected' : 'Disconnected',
          onPressed: onToggleConnection,
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE9EAF0)),
      ),
    );
  }
}
