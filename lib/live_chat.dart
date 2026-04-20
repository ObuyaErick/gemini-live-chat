import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webs/agents/agents.dart';
import 'package:webs/models/agent_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

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

  const ToolEvent({
    required this.name,
    this.args,
    this.result,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

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

  String? get modelId => _selectedAgent?.modelId;

  @override
  void initState() {
    super.initState();
    _agents = agentModels;
    _selectedAgent = _agents.cast<Agent?>().firstWhere(
          (a) => a?.agentId == 'concierge',
          orElse: () => _agents.isNotEmpty ? _agents.first : null,
        );
    _agentId = _selectedAgent?.agentId ?? 'concierge';
    _inputController = TextEditingController(text: _defaultPromptFor(_selectedAgent));
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
      // Tool call started — show activity indicator
      case 'tool_call':
        setState(() {
          _activeToolEvents.add(
            ToolEvent(
              name: payload['name'] as String,
              args: (payload['args'] as Map?)?.cast<String, dynamic>(),
            ),
          );
        });

      // Tool result received — annotate the event
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

      // Streaming token — append to the in-progress assistant message
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

      // Final assembled response — mark streaming complete, clear tool events
      case 'final':
        setState(() {
          if (_streamingMessage != null) {
            _streamingMessage!.status = MessageStatus.complete;
            _streamingMessage = null;
          } else {
            // No deltas came through (e.g. empty response) — add the full message
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

      // Error frame from server
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final agentName = _selectedAgent?.agentName ?? 'Agent';
    final agentShortName = _shortAgentName(_selectedAgent);
    final agentSubtitle = _selectedAgent?.agentSubtitle;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(colorScheme),
      body: Column(
        children: [
          // Connection error banner
          if (_connectionError != null)
            _ErrorBanner(message: _connectionError!, onRetry: _connect),

          // Tool activity strip
          if (_activeToolEvents.isNotEmpty)
            _ToolActivityStrip(events: _activeToolEvents),

          // Message list
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(
                    agentName: agentName,
                    subtitle: agentSubtitle,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _MessageBubble(message: _messages[i]),
                  ),
          ),

          // Input bar
          _InputBar(
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

  AppBar _buildAppBar(ColorScheme colorScheme) {
    final agentName = _selectedAgent?.agentName ?? 'Agent';
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: agentName, style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: ' ($modelId)', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (_agents.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Agent>(
                value: _selectedAgent,
                onChanged: (a) {
                  if (a == null) return;
                  _switchAgent(a);
                },
                items: _agents
                    .map(
                      (a) => DropdownMenuItem<Agent>(
                        value: a,
                        child: Text(
                          a.agentName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        IconButton(
          icon: Icon(_isConnected ? Icons.link_off : Icons.link),
          tooltip: _isConnected ? 'Disconnect' : 'Connect',
          onPressed: _isConnected ? _disconnect : _connect,
        ),
        SizedBox(width: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ToolActivityStrip extends StatelessWidget {
  final List<ToolEvent> events;

  const _ToolActivityStrip({required this.events});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Show the most recent pending tool call
    final pending = events.lastWhere(
      (e) => e.result == null,
      orElse: () => events.last,
    );
    final isDone = pending.result != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: colorScheme.secondaryContainer.withOpacity(0.6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (!isDone)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.check_circle_outline, size: 14),
          const SizedBox(width: 8),
          Text(
            isDone ? '${pending.name} → done' : 'Calling ${pending.name}…',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          if (events.length > 1) ...[
            const SizedBox(width: 8),
            Text(
              '+${events.length - 1} more',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSecondaryContainer.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isError = message.status == MessageStatus.error;
    final isStreaming = message.status == MessageStatus.streaming;
    final colorScheme = Theme.of(context).colorScheme;

    final bubbleColor = isError
        ? colorScheme.errorContainer
        : isUser
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;

    final textColor = isError
        ? colorScheme.onErrorContainer
        : isUser
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isError)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 14,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Error',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.content,
              style: TextStyle(fontSize: 15, color: textColor, height: 1.45),
            ),
            if (isStreaming)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _CursorBlink(color: textColor.withOpacity(0.5)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CursorBlink extends StatefulWidget {
  final Color color;
  const _CursorBlink({required this.color});

  @override
  State<_CursorBlink> createState() => _CursorBlinkState();
}

class _CursorBlinkState extends State<_CursorBlink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String agentName;
  final String? subtitle;
  const _EmptyState({required this.agentName, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 48,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            agentName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle?.trim().isNotEmpty == true
                ? subtitle!.trim()
                : 'Ask me anything.',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isWaiting;
  final String agentShortName;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.isWaiting,
    required this.agentShortName,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
                decoration: InputDecoration(
                  hintText: isWaiting
                      ? '$agentShortName is thinking…'
                      : 'Ask $agentShortName…',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isWaiting
                  ? Padding(
                      key: const ValueKey('waiting'),
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.primary,
                        ),
                      ),
                    )
                  : IconButton.filled(
                      key: const ValueKey('send'),
                      onPressed: enabled ? onSend : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
