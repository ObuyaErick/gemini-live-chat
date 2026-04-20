import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webs/agents/agents.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/widgets/date_pill.dart';
import 'package:webs/live_chat/widgets/empty_state.dart';
import 'package:webs/live_chat/widgets/error_banner.dart';
import 'package:webs/live_chat/widgets/input_bar.dart';
import 'package:webs/live_chat/widgets/message_bubble.dart';
import 'package:webs/live_chat/widgets/tool_call_chip.dart';
import 'package:webs/models/agent_models.dart';

class LiveChat extends StatefulWidget {
  const LiveChat({super.key});

  @override
  State<LiveChat> createState() => _LiveChatState();
}

class _LiveChatState extends State<LiveChat> {
  WebSocketChannel? _channel;
  final List<ChatMessage> _messages = [];
  final List<ToolEvent> _activeToolEvents = [];
  late final TextEditingController _inputController;
  final ScrollController _scrollController = ScrollController();
  bool _isConnected = false;
  bool _isWaitingForResponse = false;
  String? _connectionError;
  late final List<Agent> _agents;
  Agent? _selectedAgent;
  late String _agentId;

  // The in-progress assistant message being built from delta chunks
  ChatMessage? _streamingMessage;

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
      text: _defaultPromptFor(_selectedAgent),
    );
    _connect();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _inputController.dispose();
    _scrollController.dispose();
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
      _isWaitingForResponse = false;
      _connectionError = null;
      _inputController.text = _defaultPromptFor(agent);
    });

    _disconnect();
    _connect();
  }

  // ------------------------------------------------------------------
  // Connection
  // ------------------------------------------------------------------

  void _connect() {
    setState(() {
      _connectionError = null;
      _isConnected = false;
    });

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(
          'ws://localhost:8000/chat/$_agentId?token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJlcmlja0ByZWR1emVyLnRlY2giLCJzY29wZSI6ImFkbWluIiwicHJvamVjdCI6Indpbi1wLW1vYmlsZXVuaXZlcnNlIiwiYWNjb3VudCI6Im1vYmlsZV91bml2ZXJzZV9hcGkiLCJkcml2ZUlkIjoiMEFQSnJac1JFbWxPOVVrOVBWQSIsImlzcyI6Im9yZ2FuaXphdGlvbkBib3hhbGluby5jb20iLCJqdGkiOiI0ZDgzOTgxMjVlYzkxZjBmYjJiNmFkNTc2NWU2OTY0ZDYyNDM0YWM1IiwiZXhwIjoxNzc2NzE4NjUzLCJjcmVhdGVkIjoiMjAyNi0wNC0yMCAxMDo1Nzo0MCJ9.8tAoWa7On1LaiJAgh-Lm6bb2vwguFoXutVmGLsU89h0',
        ),
      );
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      setState(() => _isConnected = true);
    } catch (e) {
      setState(() => _connectionError = 'Connection failed: $e');
    }
  }

  void _disconnect() {
    _channel?.sink.close();
    setState(() {
      _isConnected = false;
      _isWaitingForResponse = false;
      _streamingMessage = null;
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

    switch (type) {
      case 'tool_call':
        setState(() {
          _activeToolEvents.add(
            ToolEvent(
              name: payload['name'] as String,
              args: (payload['args'] as Map?)?.cast<String, dynamic>(),
            ),
          );
        });

      case 'tool_result':
        setState(() {
          final name = payload['name'] as String;
          final idx = _activeToolEvents.indexWhere(
            (e) => e.name == name && e.result == null,
          );
          if (idx != -1) {
            final old = _activeToolEvents[idx];
            _activeToolEvents[idx] = ToolEvent(
              name: old.name,
              args: old.args,
              result: (payload['result'] as Map?)?.cast<String, dynamic>(),
            );
          }
        });

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

      case 'error':
        final errMsg = payload['content'] as String? ?? 'Unknown error';
        setState(() {
          _streamingMessage?.status = MessageStatus.error;
          _streamingMessage = null;
          _activeToolEvents.clear();
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

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final agentName = _selectedAgent?.agentName ?? 'Agent';
    final agentShortName = _shortAgentName(_selectedAgent);
    final agentSubtitle = _selectedAgent?.agentSubtitle;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: _LiveChatAppBar(
        isConnected: _isConnected,
        agents: _agents,
        selectedAgent: _selectedAgent,
        onSelectAgent: _switchAgent,
        onToggleConnection: _isConnected ? _disconnect : _connect,
      ),
      body: Column(
        children: [
          if (_connectionError != null)
            ErrorBanner(message: _connectionError!, onRetry: _connect),
          Expanded(
            child: Stack(
              children: [
                _messages.isEmpty
                    ? EmptyState(agentName: agentName, subtitle: agentSubtitle)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                        itemCount:
                            _messages.length +
                            (_activeToolEvents.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (_activeToolEvents.isNotEmpty && i == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ToolCallChip(events: _activeToolEvents),
                            );
                          }
                          final msgIndex =
                              i - (_activeToolEvents.isNotEmpty ? 1 : 0);
                          return MessageBubble(
                            message: _messages[msgIndex],
                            agentName: agentName,
                            formatTime: _formatTime,
                          );
                        },
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
          InputBar(
            controller: _inputController,
            enabled: _isConnected && !_isWaitingForResponse,
            isWaiting: _isWaitingForResponse,
            agentShortName: agentShortName,
            onSend: _sendMessage,
          ),
        ],
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

  const _LiveChatAppBar({
    required this.isConnected,
    required this.agents,
    required this.selectedAgent,
    required this.onSelectAgent,
    required this.onToggleConnection,
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
      titleSpacing: 20,
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
                Text(
                  isConnected ? 'STATUS: CONNECTED' : 'STATUS: DISCONNECTED',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
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
