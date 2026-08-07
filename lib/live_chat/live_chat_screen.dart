import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webs/extensions/date_time_extensions.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';
import 'package:webs/live_chat/providers/live_chat_ui_event.dart';
import 'package:webs/live_chat/widgets/action_confirmation_card.dart';
import 'package:webs/live_chat/widgets/centered_band.dart';
import 'package:webs/live_chat/widgets/clarification_card.dart';
import 'package:webs/live_chat/widgets/date_pill.dart';
import 'package:webs/live_chat/widgets/document_editor_panel.dart';
import 'package:webs/live_chat/widgets/empty_state.dart';
import 'package:webs/live_chat/widgets/error_banner.dart';
import 'package:webs/live_chat/widgets/input_bar.dart';
import 'package:webs/live_chat/widgets/live_chat_appbar.dart';
import 'package:webs/live_chat/widgets/message_bubble.dart';
import 'package:webs/live_chat/widgets/sessions_sidebar.dart';
import 'package:webs/live_chat/widgets/suggestion_card.dart';
import 'package:webs/live_chat/widgets/tool_call_chip.dart';
import 'package:webs/models/agent_models.dart';
import 'package:webs/ui/core/app_theme.dart';
import 'package:webs/ui/core/horizontal_layout_breakpoints.dart';

/// The live-chat surface. A thin view over [LiveChatProvider]: it owns only
/// view-local controllers (scroll, input text, drawer state) and relays the
/// provider's one-shot UI events (snackbars, scroll) which the provider itself
/// cannot perform without a [BuildContext].
class LiveChat extends StatefulWidget {
  final ChatContext? chatContext;

  const LiveChat({super.key, this.chatContext});

  @override
  State<LiveChat> createState() => _LiveChatState();
}

class _LiveChatState extends State<LiveChat> {
  late final LiveChatProvider _provider;
  StreamSubscription<LiveChatUiEvent>? _uiSub;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarOpen = true;

  @override
  void initState() {
    super.initState();
    _provider = LiveChatProvider();
    _provider.addListener(_onProviderChanged);
    _uiSub = _provider.uiEvents.listen(_handleUiEvent);
    // Deferred so the provider's first synchronous notify doesn't call
    // setState during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.initialize(chatContext: widget.chatContext);
    });
  }

  @override
  void dispose() {
    _uiSub?.cancel();
    _provider.removeListener(_onProviderChanged);
    _provider.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  void _handleUiEvent(LiveChatUiEvent event) {
    if (!mounted) return;
    switch (event) {
      case ShowSnackBar():
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(event.message),
            duration: event.duration,
            action: event.dismissible
                ? SnackBarAction(
                    label: 'Dismiss',
                    onPressed: messenger.hideCurrentSnackBar,
                  )
                : null,
          ),
        );
      case ScrollToBottom():
        _scrollToBottom();
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

  void _send() {
    if (!_provider.isConnected || _provider.isWaitingForResponse) return;
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _provider.sendMessage(text);
    _inputController.clear();
  }

  void _toggleSidebar() => setState(() => _isSidebarOpen = !_isSidebarOpen);

  String _shortAgentName(Agent? agent) {
    final name = agent?.agentName.trim();
    if (name == null || name.isEmpty) return 'Agent';
    final first = name.split(RegExp(r'\s+')).first;
    return first.isEmpty ? name : first;
  }

  Widget _buildEditorPanel() => SizedBox(
    width: 440,
    child: DocumentEditorPanel(
      documents: _provider.openDocuments,
      activeFileId: _provider.activeDocumentFileId,
      onSelectDocument: _provider.selectDocument,
      onClose: _provider.closeDocument,
      onUserEdit: _provider.submitUserDocumentEdit,
      pendingProposals: _provider.pendingProposals,
      onAcceptProposal: _provider.acceptProposal,
      onRejectProposal: _provider.rejectProposal,
    ),
  );

  Widget _buildChatArea() {
    final agent = _provider.selectedAgent;
    final agentName = agent?.agentName ?? 'Agent';
    final now = DateTime.now();

    return Column(
      children: [
        if (_provider.connectionError != null)
          ErrorBanner(
            message: _provider.connectionError!,
            onRetry: _provider.connect,
          ),
        Expanded(
          child: Stack(
            children: [
              _provider.messages.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 48,
                      ),
                      child: EmptyState(
                        agentName: agentName,
                        subtitle: agent?.agentSubtitle,
                        actions: [
                          if (_provider.suggestedQuestions.isNotEmpty)
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final q in _provider.suggestedQuestions)
                                  SuggestionCard(
                                    text: q.questionText,
                                    onTap: () =>
                                        _provider.sendMessage(q.questionText),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final message in _provider.messages)
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 760,
                                ),
                                child: MessageBubble(
                                  message: message,
                                  formatTime: (dt) => dt.chatTime,
                                ),
                              ),
                            ),

                          SizedBox(height: 16),
                        ],
                      ),
                    ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: DatePill(text: now.chatTodayPill),
                ),
              ),
            ],
          ),
        ),
        if (_provider.activeToolEvents.isNotEmpty)
          CenteredBand(child: ToolCallChip(events: _provider.activeToolEvents)),
        if (_provider.pendingAction != null)
          CenteredBand(
            child: ActionConfirmationCard(
              action: _provider.pendingAction!,
              onConfirm: _provider.confirmAction,
              onCancel: _provider.cancelAction,
            ),
          ),
        if (_provider.pendingClarification != null)
          CenteredBand(
            child: ClarificationCard(
              clarification: _provider.pendingClarification!,
              onSubmit: _provider.sendElicitResponse,
            ),
          ),

        InputBar(
          controller: _inputController,
          enabled: _provider.isConnected && !_provider.isWaitingForResponse,
          isWaiting: _provider.isWaitingForResponse,
          agentShortName: _shortAgentName(agent),
          onSend: _send,
          onAttach: _provider.pickFiles,
          stagedFiles: _provider.stagedFiles,
          onRemoveStagedFile: _provider.removeStagedFile,
          isInLiveMode: _provider.isInLiveMode,
          onToggleLiveMode: _provider.isConnected
              ? (_provider.isInLiveMode
                    ? _provider.endLiveMode
                    : _provider.startLiveMode)
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LiveChatProvider>.value(
      value: _provider,
      child: HorizontalLayoutBreakpoints(
        all: (context, _) => Scaffold(
          key: _scaffoldKey,
          backgroundColor: context.tokens.bgApp,
          drawer: Drawer(
            width: SessionsSidebar.openWidth,
            child: SessionsSidebar(
              onSelectSession: (s) {
                _provider.selectSession(s);
                _scaffoldKey.currentState?.closeDrawer();
              },
              onNewSession: () {
                _provider.newSession();
                _scaffoldKey.currentState?.closeDrawer();
              },
              onEvictAllSessions: () {
                _provider.evictAllSessions();
                _scaffoldKey.currentState?.closeDrawer();
              },
              onEvictSession: (s) {
                _provider.evictSession(s.sessionId);
                _scaffoldKey.currentState?.closeDrawer();
              },
              isOpen: true,
              onToggle: () => _scaffoldKey.currentState?.closeDrawer(),
            ),
          ),
          appBar: LiveChatAppBar(
            isConnected: _provider.isConnected,
            agents: _provider.agents,
            selectedAgent: _provider.selectedAgent,
            onSelectAgent: _provider.switchAgent,
            onToggleConnection: _provider.isConnected
                ? _provider.disconnect
                : _provider.connect,
            isSidebarOpen: false,
            onToggleSidebar: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          body: Row(
            children: [
              Expanded(flex: 2, child: _buildChatArea()),
              if (_provider.openDocuments.isNotEmpty) _buildEditorPanel(),
            ],
          ),
        ),
        md: (context, _) => Scaffold(
          key: _scaffoldKey,
          backgroundColor: context.tokens.bgApp,
          appBar: LiveChatAppBar(
            isConnected: _provider.isConnected,
            agents: _provider.agents,
            selectedAgent: _provider.selectedAgent,
            onSelectAgent: _provider.switchAgent,
            onToggleConnection: _provider.isConnected
                ? _provider.disconnect
                : _provider.connect,
            isSidebarOpen: _isSidebarOpen,
            onToggleSidebar: _toggleSidebar,
          ),
          body: Row(
            children: [
              SessionsSidebar(
                onSelectSession: _provider.selectSession,
                onNewSession: _provider.newSession,
                onEvictSession: (s) => _provider.evictSession(s.sessionId),
                onEvictAllSessions: _provider.evictAllSessions,
                isOpen: _isSidebarOpen,
                onToggle: _toggleSidebar,
              ),
              Expanded(flex: 2, child: _buildChatArea()),
              if (_provider.openDocuments.isNotEmpty) _buildEditorPanel(),
            ],
          ),
        ),
      ),
    );
  }
}
