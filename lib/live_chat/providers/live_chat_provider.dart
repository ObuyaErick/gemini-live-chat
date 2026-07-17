import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:webs/api/api_client.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/providers/live_chat_ui_event.dart';
import 'package:webs/live_chat/services/agent_service.dart';
import 'package:webs/live_chat/services/chat_socket_service.dart';
import 'package:webs/live_chat/services/pcm_audio_player.dart';
import 'package:webs/models/agent_models.dart';

/// The single source of truth for a live-chat surface: the `/chat/` connection,
/// the transcript, tool/action/clarification state, editable documents, live
/// (voice) mode, the agent roster, and the session list.
///
/// Layering (per CLAUDE.md): the widget tree only reads this provider's state
/// and calls its intent methods; all socket I/O goes through
/// [ChatSocketService] and audio through [PcmAudioPlayer]. The provider holds
/// no [BuildContext] — one-shot UI effects (snackbars, scroll) are surfaced on
/// [uiEvents].
class LiveChatProvider extends ChangeNotifier {
  LiveChatProvider({
    ChatSocketService? socket,
    PcmAudioPlayer? audioPlayer,
    AgentService? agentService,
  }) : _socket = socket ?? ChatSocketService(),
       _audioPlayer = audioPlayer ?? PcmAudioPlayer(),
       _agentService = agentService ?? AgentService();

  final ChatSocketService _socket;
  final PcmAudioPlayer _audioPlayer;
  final AgentService _agentService;
  final StreamController<LiveChatUiEvent> _uiEvents =
      StreamController<LiveChatUiEvent>.broadcast();

  // ---- Agents & connection -------------------------------------------------
  List<Agent> _agents = const [];
  Agent? _selectedAgent;
  ChatContext? _chatContext;

  // The agent named in the connect URL — the session's *initial* agent (v12
  // §6.7). Only changes when we open a new socket (new/selected session).
  String _agentId = 'concierge';

  // The agent the server is currently routing turns to for this shared session.
  // Starts as the connect agent and moves on `agent_switched`. `agent_id` is
  // sticky, so [sendMessage] only sends it while [_selectedAgent] differs.
  String? _activeAgentId;

  // Bumped on every (re)connect. Socket callbacks capture the generation they
  // were registered under and ignore events from a superseded channel.
  int _connectionGeneration = 0;

  bool _isConnected = false;
  String? _connectionError;
  bool _isWaitingForResponse = false;
  bool _isInLiveMode = false;

  // ---- Conversation --------------------------------------------------------
  final List<ChatMessage> _messages = [];
  final List<ToolEvent> _activeToolEvents = [];
  ChatMessage? _streamingMessage;
  PendingAction? _pendingAction;
  PendingClarification? _pendingClarification;

  // ---- Editable documents --------------------------------------------------
  final Map<String, TextDocument> _openDocuments = {};
  String? _activeDocumentFileId;
  // AI-proposed diffs awaiting accept/reject (text_diff is always a proposal).
  final Map<String, String> _pendingProposals = {};
  final Map<String, int> _proposalFromVersions = {};

  // ---- Staged uploads ------------------------------------------------------
  final List<LocalFileAttachment> _stagedFiles = [];

  // ---- Live-mode audio -----------------------------------------------------
  final List<int> _pendingAudioBytes = [];
  int _liveAudioSampleRate = 16000;

  // ---- Sessions ------------------------------------------------------------
  final Map<String, ChatSession> _sessions = {};
  String? _currentSessionId;
  bool _loadingSessions = false;
  String? _sessionsError;

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

  // ---- Public read-only state ---------------------------------------------
  Stream<LiveChatUiEvent> get uiEvents => _uiEvents.stream;

  List<Agent> get agents => List.unmodifiable(_agents);
  Agent? get selectedAgent => _selectedAgent;
  List<SuggestedQuestion> get suggestedQuestions =>
      _selectedAgent?.suggestedQuestions ?? const [];

  bool get isConnected => _isConnected;
  String? get connectionError => _connectionError;
  bool get isWaitingForResponse => _isWaitingForResponse;
  bool get isInLiveMode => _isInLiveMode;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ToolEvent> get activeToolEvents => List.unmodifiable(_activeToolEvents);
  PendingAction? get pendingAction => _pendingAction;
  PendingClarification? get pendingClarification => _pendingClarification;

  Map<String, TextDocument> get openDocuments =>
      Map.unmodifiable(_openDocuments);
  String? get activeDocumentFileId => _activeDocumentFileId;
  Map<String, String> get pendingProposals =>
      Map.unmodifiable(_pendingProposals);

  List<LocalFileAttachment> get stagedFiles => List.unmodifiable(_stagedFiles);

  Map<String, ChatSession> get sessions => Map.unmodifiable(_sessions);
  String? get currentSessionId => _currentSessionId;
  bool get loadingSessions => _loadingSessions;
  String? get sessionsError => _sessionsError;

  List<ChatSession> get sessionsByDateDesc {
    final list = _sessions.values.toList()
      ..sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    return list;
  }

  // ---- Lifecycle -----------------------------------------------------------

  /// Wires the optional module context, loads the agent roster and session
  /// list, and opens the connection to the concierge. Call once from the
  /// screen's `initState`. Agents load in parallel with the connection — the
  /// concierge id is fixed, so we don't wait for the roster to connect.
  void initialize({ChatContext? chatContext}) {
    _chatContext = chatContext;
    _agentId = 'concierge';
    _activeAgentId = 'concierge';
    loadAgents();
    loadSessions();
    connect();
  }

  /// Fetches the agent roster from `GET /agents`. On failure the picker is left
  /// empty and the error is surfaced — the concierge connection still works
  /// since its id is fixed. Keeps the current selection when it survives the
  /// refresh, else defaults to the concierge.
  Future<void> loadAgents() async {
    try {
      _agents = await _agentService.fetchAgents();
    } catch (e) {
      _agents = const [];
      _emit(
        ShowSnackBar(
          'Failed to load agents: $e',
          duration: const Duration(seconds: 6),
        ),
      );
    }
    _selectedAgent =
        _agentById(_selectedAgent?.agentId) ??
        _agentById('concierge') ??
        (_agents.isNotEmpty ? _agents.first : null);
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionGeneration++;
    _socket.disconnect();
    _audioPlayer.dispose();
    _uiEvents.close();
    super.dispose();
  }

  // ---- Connection ----------------------------------------------------------

  Future<void> connect() async {
    final gen = ++_connectionGeneration;
    _connectionError = null;
    _isConnected = false;
    // Fresh baseline for this connection; refined from history for resumes.
    _activeAgentId = _agentId;
    notifyListeners();

    try {
      final params = <String, String?>{
        'session_id': _currentSessionId,
        'go_auth_token': ApiClient.goAuthToken,
        'token': ApiClient.token,
      }..removeWhere((_, v) => v == null);
      final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final url = '${ApiClient.baseWebsocketUrl}/chat/$_agentId?$query';

      await _socket.connect(
        url: url,
        onFrame: (frame) => _onFrame(gen, frame),
        onError: (error) => _onSocketError(gen, error),
        onDone: () => _onSocketDone(gen),
      );
      if (gen != _connectionGeneration) return; // superseded by a newer connect
      _isConnected = true;
      notifyListeners();
      _pushContextIfApplicable();
    } catch (e) {
      if (gen != _connectionGeneration) return;
      _connectionError = 'Connection failed: $e';
      notifyListeners();
    }
  }

  /// Closes the connection and resets transient session state, keeping the
  /// visible transcript. Used by the connection toggle.
  void disconnect() {
    _connectionGeneration++;
    _socket.disconnect();
    _pendingAudioBytes.clear();
    _audioPlayer.stop();
    _isConnected = false;
    _isWaitingForResponse = false;
    _isInLiveMode = false;
    _streamingMessage = null;
    _pendingAction = null;
    _pendingClarification = null;
    _activeToolEvents.clear();
    _openDocuments.clear();
    _activeDocumentFileId = null;
    _pendingProposals.clear();
    _proposalFromVersions.clear();
    notifyListeners();
  }

  void _pushContextIfApplicable() {
    final ctx = _chatContext;
    // Keyed on the connection agent, not the (possibly still-loading) selection.
    if (ctx == null || _agentId != 'concierge') return;
    // Non-fatal: a broken socket surfaces via the regular error path.
    _socket.send({'context': ctx.toJson()});
  }

  // ---- Agent / session selection ------------------------------------------

  /// Hand the conversation to [agent] (v12 §6.7). This does **not** open a new
  /// socket or start a new session — a session is a shared transcript. We keep
  /// the same connection and transcript and send the chosen `agent_id` on the
  /// next user turn ([sendMessage]); the server confirms with `agent_switched`
  /// and the incoming agent inherits the full prior transcript. `agent_id` is
  /// sticky, so it is only sent while the selection differs from [_activeAgentId].
  void switchAgent(Agent agent) {
    if (_selectedAgent?.agentId == agent.agentId) return;
    _selectedAgent = agent;
    _connectionError = null;
    notifyListeners();
  }

  /// Resume an existing shared session. Reconnects bound to the session's
  /// initial agent; the last participant is restored from the history replay.
  void selectSession(ChatSession session) {
    if (_currentSessionId == session.sessionId) return;
    _resetConversationState();
    _currentSessionId = session.sessionId;
    final sessionAgentId = session.agentId;
    if (sessionAgentId != null) {
      _agentId = sessionAgentId;
      _selectedAgent = _agentById(sessionAgentId) ?? _selectedAgent;
    }
    notifyListeners();
    connect();
  }

  /// Start a fresh conversation with the currently selected agent.
  void newSession() {
    _resetConversationState();
    _currentSessionId = null;
    _agentId = _selectedAgent?.agentId ?? _agentId;
    notifyListeners();
    connect();
  }

  void _resetConversationState() {
    _messages.clear();
    _activeToolEvents.clear();
    _streamingMessage = null;
    _pendingAction = null;
    _pendingClarification = null;
    _isWaitingForResponse = false;
    _isInLiveMode = false;
    _connectionError = null;
    _openDocuments.clear();
    _activeDocumentFileId = null;
    _pendingProposals.clear();
    _proposalFromVersions.clear();
    _stagedFiles.clear();
    _pendingAudioBytes.clear();
  }

  Agent? _agentById(String? id) {
    if (id == null) return null;
    for (final a in _agents) {
      if (a.agentId == id) return a;
    }
    return null;
  }

  // ---- Sessions API --------------------------------------------------------

  Future<void> loadSessions([String? _]) async {
    _loadingSessions = true;
    _sessionsError = null;
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/threads'),
        headers: {
          if (ApiClient.token != null) 'x-winp-token': ApiClient.token!,
        },
      );
      if (res.statusCode != 200) {
        throw Exception('${res.statusCode} ${res.reasonPhrase ?? ''}');
      }
      final list = (jsonDecode(res.body) as List).whereType<Map>().toList();
      _sessions.clear();
      for (final m in list) {
        final session = ChatSession.fromJson(m.cast<String, dynamic>());
        if (session.isStandard) _sessions[session.sessionId] = session;
      }
      _loadingSessions = false;
    } catch (e) {
      _loadingSessions = false;
      _sessionsError = 'Failed to load sessions: $e';
    }
    notifyListeners();
  }

  Future<void> evictSession(String sessionId) async {
    await http.delete(
      Uri.parse('${ApiClient.baseUrl}/sessions/$sessionId/evict'),
      headers: {if (ApiClient.token != null) 'x-winp-token': ApiClient.token!},
    );
    _sessions.remove(sessionId);
    if (_currentSessionId == sessionId) {
      newSession();
    } else {
      notifyListeners();
    }
  }

  Future<void> evictAllSessions() async {
    await http.delete(
      Uri.parse('${ApiClient.baseUrl}/sessions/evict'),
      headers: {if (ApiClient.token != null) 'x-winp-token': ApiClient.token!},
    );
    _sessions.clear();
    newSession();
  }

  void _updateCurrentSessionPreview(String preview) {
    final id = _currentSessionId;
    if (id == null) return;
    final session = _sessions[id];
    if (session == null) return;
    _sessions[id] = session.copyWith(preview: preview);
  }

  void _registerSessionFromServer(Map<String, dynamic> content) {
    final session = ChatSession.fromJson(content);
    if (!session.isStandard) return;
    if (!_sessions.containsKey(session.sessionId)) {
      _sessions[session.sessionId] = session.copyWith(preview: 'NEW');
    }
    _currentSessionId = session.sessionId;
    notifyListeners();
  }

  // ---- Sending -------------------------------------------------------------

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !_isConnected || _isWaitingForResponse) return;

    final files = _stagedFiles.toList();
    _messages.add(
      ChatMessage(
        role: MessageRole.user,
        content: trimmed,
        localAttachments: files,
      ),
    );
    _isWaitingForResponse = true;
    _stagedFiles.clear();
    notifyListeners();
    _emit(const ScrollToBottom());

    final payload = <String, dynamic>{'text': trimmed};
    // v12 §6.7: sticky agent switch — send agent_id only while our selection
    // differs from the agent the server is currently using.
    final selectedId = _selectedAgent?.agentId;
    if (selectedId != null && selectedId != _activeAgentId) {
      payload['agent_id'] = selectedId;
    }
    if (_activeDocumentFileId != null) {
      payload['focused_file_id'] = _activeDocumentFileId;
    }
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

    try {
      if (!_socket.send(payload)) throw StateError('no active connection');
    } catch (e) {
      _isWaitingForResponse = false;
      _messages.add(
        ChatMessage(
          role: MessageRole.assistant,
          content: 'Failed to send: $e',
          status: MessageStatus.error,
        ),
      );
      notifyListeners();
    }
  }

  void confirmAction() => _sendActionDecision(confirmed: true);
  void cancelAction() => _sendActionDecision(confirmed: false);

  void _sendActionDecision({required bool confirmed}) {
    final pending = _pendingAction;
    if (pending == null || !_isConnected) return;
    _pendingAction = null;
    notifyListeners();
    _socket.send({
      'type': confirmed ? 'action_confirm' : 'action_cancel',
      'tool_name': pending.toolName,
    });
  }

  void sendElicitResponse(List<List<String>> answers) {
    final pending = _pendingClarification;
    if (pending == null || !_isConnected) return;
    _pendingClarification = null;
    notifyListeners();
    _socket.send({
      'type': 'elicit_response',
      'tool_name': pending.toolName,
      'answers': answers,
    });
  }

  void startLiveMode() {
    if (!_isConnected || _isInLiveMode || _isWaitingForResponse) return;
    _socket.send({'type': 'start_live'});
  }

  void endLiveMode() {
    if (!_isConnected || !_isInLiveMode) return;
    _socket.send({'end_live': true});
  }

  // ---- Editable documents --------------------------------------------------

  void selectDocument(String fileId) {
    _activeDocumentFileId = fileId;
    notifyListeners();
  }

  void closeDocument(String fileId) {
    _openDocuments.remove(fileId);
    _pendingProposals.remove(fileId);
    _proposalFromVersions.remove(fileId);
    if (_activeDocumentFileId == fileId) {
      _activeDocumentFileId = _openDocuments.isEmpty
          ? null
          : _openDocuments.keys.first;
    }
    notifyListeners();
  }

  /// Accept an AI-proposed diff. Applies it locally and advances the version;
  /// the server copy is unchanged until a `document_edit` is relayed (kept
  /// disabled here, matching the prior behaviour of local-only apply).
  void acceptProposal(String fileId) {
    final diff = _pendingProposals[fileId];
    if (diff == null || diff.isEmpty) return;
    final fromVersion = _proposalFromVersions[fileId] ?? 0;
    _openDocuments[fileId]?.applyDiff(
      diff,
      fromVersion: fromVersion,
      toVersion: fromVersion + 1,
    );
    _pendingProposals.remove(fileId);
    _proposalFromVersions.remove(fileId);
    notifyListeners();
    // _sendDocumentEdit(fileId, diff, origin: 'agent');
  }

  void rejectProposal(String fileId) {
    _pendingProposals.remove(fileId);
    _proposalFromVersions.remove(fileId);
    notifyListeners();
  }

  /// Commit a manual user edit: relay the diff and advance the local copy so
  /// the next diff is computed from the correct base (no server reply on
  /// success).
  void submitUserDocumentEdit(String fileId, String diff, String newText) {
    _sendDocumentEdit(fileId, diff);
    _openDocuments[fileId]?.resetFromResync(
      newText,
      (_openDocuments[fileId]!.version) + 1,
    );
    notifyListeners();
  }

  void _sendDocumentEdit(String fileId, String diff, {String origin = 'user'}) {
    if (diff.isEmpty) return;
    _socket.send({
      'type': 'document_edit',
      'content': {'file_id': fileId, 'diff': diff, 'origin': origin},
    });
  }

  Future<void> _fetchAndOpenDocument(
    Attachment att, {
    List<Map<String, dynamic>> edits = const [],
  }) async {
    if (att.url.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(att.url));
      if (response.statusCode != 200) {
        debugPrint('[doc-fetch] ${att.filename}: HTTP ${response.statusCode}');
        return;
      }
      final doc = TextDocument(
        fileId: att.fileId,
        filename: att.filename,
        mimeType: att.mimeType,
        lines: response.body.split('\n'),
      );
      // Replay only edits that belong to this document, in timeline order.
      for (final edit in edits) {
        if ((edit['file_id'] as String?) != att.fileId) continue;
        doc.applyDiff(
          edit['diff'] as String? ?? '',
          fromVersion: (edit['from_version'] as num?)?.toInt() ?? 0,
          toVersion: (edit['to_version'] as num?)?.toInt() ?? 0,
        );
      }
      _openDocuments[att.fileId] = doc;
      _activeDocumentFileId ??= att.fileId;
      notifyListeners();
    } catch (e) {
      debugPrint('[doc-fetch] ${att.filename}: $e');
    }
  }

  // ---- Uploads -------------------------------------------------------------

  Future<void> pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

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

    _stagedFiles.addAll(picked);
    notifyListeners();
    if (errors.isNotEmpty) {
      _emit(
        ShowSnackBar(errors.join('\n'), duration: const Duration(seconds: 6)),
      );
    }
  }

  void removeStagedFile(LocalFileAttachment file) {
    _stagedFiles.remove(file);
    notifyListeners();
  }

  // ---- Inbound frame dispatch ---------------------------------------------

  void _onFrame(int gen, Map<String, dynamic> payload) {
    if (gen != _connectionGeneration) return; // stale channel
    final type = payload['type'] as String?;

    if (type == 'final' && _messages.length <= 2 && _messages.isNotEmpty) {
      _updateCurrentSessionPreview(_messages.first.content);
    }

    switch (type) {
      case 'session':
        final content = (payload['content'] as Map?)?.cast<String, dynamic>();
        if (content != null) _registerSessionFromServer(content);

      case 'history':
        _handleHistory(payload);

      case 'tool_call':
        final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        _activeToolEvents.add(
          ToolEvent(
            name: c['name'] as String,
            args: (c['args'] as Map?)?.cast<String, dynamic>(),
          ),
        );
        notifyListeners();

      case 'tool_result':
        final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final name = c['name'] as String;
        final idx = _activeToolEvents.indexWhere(
          (e) => e.name == name && e.result == null,
        );
        if (idx != -1) {
          final old = _activeToolEvents[idx];
          _activeToolEvents[idx] = ToolEvent(
            name: old.name,
            args: old.args,
            result: (c['result'] as Map?)?.cast<String, dynamic>(),
          );
          notifyListeners();
        }

      case 'action_confirmation':
        final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        _pendingAction = PendingAction(
          toolName: (c['tool_name'] as String?) ?? 'action',
          summary: (c['summary'] as String?) ?? 'Confirm action?',
          parameters:
              (c['parameters'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
        notifyListeners();
        _emit(const ScrollToBottom());

      case 'clarification':
        final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final rawQuestions = (c['questions'] as List?) ?? const [];
        _pendingClarification = PendingClarification(
          toolName: (c['tool_name'] as String?) ?? 'ASK_USER',
          questions: rawQuestions
              .whereType<Map>()
              .map(
                (q) =>
                    ClarificationQuestion.fromJson(q.cast<String, dynamic>()),
              )
              .toList(),
        );
        notifyListeners();
        _emit(const ScrollToBottom());

      case 'agent_switched':
        final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final toAgentId = c['to_agent_id'] as String?;
        final toAgentName = c['agent_name'] as String?;
        if (toAgentId != null) {
          _activeAgentId = toAgentId;
          _selectedAgent = _agentById(toAgentId) ?? _selectedAgent;
          notifyListeners();
        }
        final label = toAgentName ?? toAgentId;
        if (label != null) _emit(ShowSnackBar('Switched to $label'));

      case 'navigate':
        final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final target = c['target'] as String?;
        if (target == null || target.isEmpty) return;
        final params = (c['params'] as Map?)?.cast<String, dynamic>();
        _emit(
          ShowSnackBar(
            params == null || params.isEmpty
                ? 'Navigate → $target'
                : 'Navigate → $target  •  $params',
            duration: const Duration(seconds: 10),
          ),
        );

      case 'delta':
        final chunk = payload['content'] as String? ?? '';
        if (chunk.isEmpty) return;
        if (_streamingMessage == null) {
          _streamingMessage = ChatMessage(
            role: MessageRole.assistant,
            content: chunk,
            status: MessageStatus.streaming,
            agentId: _activeAgentId,
          );
          _messages.add(_streamingMessage!);
        } else {
          _streamingMessage!.content += chunk;
        }
        notifyListeners();
        _emit(const ScrollToBottom());

      case 'final':
        final attachments = _parseAttachments(payload['attachments']);
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
                agentId: _activeAgentId,
              ),
            );
          }
        }
        _activeToolEvents.clear();
        _isWaitingForResponse = false;
        notifyListeners();
        for (final att in attachments.where((a) => a.isEditable)) {
          _fetchAndOpenDocument(att);
        }
        _emit(const ScrollToBottom());

      case 'image':
        final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final data = c['data'] as String? ?? '';
        if (data.isEmpty) return;
        _messages.add(
          ChatMessage(
            role: MessageRole.assistant,
            status: MessageStatus.complete,
            imageBytes: base64Decode(data),
            imageMimeType: c['mime_type'] as String? ?? 'image/png',
            agentId: _activeAgentId,
          ),
        );
        notifyListeners();
        _emit(const ScrollToBottom());

      case 'context_ack':
        final ack = (payload['content'] as Map?)?.cast<String, dynamic>();
        final label = ack?['title'] ?? ack?['page'] ?? ack?['module'];
        _emit(
          ShowSnackBar(
            label == null
                ? 'Context acknowledged'
                : 'Context acknowledged: $label',
            duration: const Duration(seconds: 20),
            dismissible: true,
          ),
        );

      case 'mode_changed':
        final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final mode = c['mode'] as String?;
        if (mode == 'standard' && _pendingAudioBytes.isNotEmpty) {
          _flushAudio();
        } else if (mode != 'live') {
          _pendingAudioBytes.clear();
        }
        _isInLiveMode = mode == 'live';
        if (mode == 'standard') _isWaitingForResponse = false;
        notifyListeners();

      case 'audio_output':
        final b64 = payload['content'] as String? ?? '';
        if (b64.isEmpty) return;
        _liveAudioSampleRate = PcmAudioPlayer.sampleRateFromMime(
          payload['mime_type'] as String? ?? '',
        );
        _pendingAudioBytes.addAll(base64Decode(b64));

      case 'output_transcript':
        final text = payload['content'] as String? ?? '';
        if (text.isEmpty) return;
        _messages.add(
          ChatMessage(
            role: MessageRole.assistant,
            content: text,
            status: MessageStatus.complete,
            isTranscript: true,
            agentId: _activeAgentId,
          ),
        );
        notifyListeners();
        _emit(const ScrollToBottom());

      case 'input_transcript':
        final text = payload['content'] as String? ?? '';
        if (text.isEmpty) return;
        _messages.add(
          ChatMessage(
            role: MessageRole.user,
            content: text,
            isTranscript: true,
          ),
        );
        notifyListeners();
        _emit(const ScrollToBottom());

      case 'turn_complete':
        if (_pendingAudioBytes.isNotEmpty) _flushAudio();

      case 'executable_code':
      case 'code_execution_result':
        // Informational native-code-execution frames — the human-facing answer
        // always follows in delta/final; drop silently.
        break;

      case 'text_diff':
        // text_diff is ALWAYS a proposal — render for accept/reject; never apply.
        final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final fileId = c['file_id'] as String?;
        if (fileId == null || !_openDocuments.containsKey(fileId)) return;
        final diff = c['diff'] as String? ?? '';
        if (diff.isEmpty) return;
        _pendingProposals[fileId] = diff;
        _proposalFromVersions[fileId] =
            (c['from_version'] as num?)?.toInt() ?? 0;
        _activeDocumentFileId = fileId;
        notifyListeners();

      case 'document_resync':
        _handleDocumentResync(payload);

      case 'error':
        final errMsg = payload['content'] as String? ?? 'Unknown error';
        _streamingMessage?.status = MessageStatus.error;
        _streamingMessage = null;
        _activeToolEvents.clear();
        _pendingAction = null;
        _pendingClarification = null;
        _isWaitingForResponse = false;
        _isInLiveMode = false;
        _messages.add(
          ChatMessage(
            role: MessageRole.assistant,
            content: errMsg,
            status: MessageStatus.error,
          ),
        );
        notifyListeners();
        _emit(const ScrollToBottom());
    }
  }

  void _handleHistory(Map<String, dynamic> payload) {
    final content =
        (payload['content'] as Map?)?.cast<String, dynamic>() ?? const {};
    final historyAgentId = content['agent_id'] as String?;
    if (historyAgentId != null && historyAgentId != _agentId) {
      // Stale frame from a previous agent connection — ignore.
      return;
    }
    final entries = (content['data'] as List?) ?? const [];

    _messages
      ..clear()
      ..addAll(
        // role: "edit" entries are document diffs, not chat bubbles — skip.
        entries
            .whereType<Map>()
            .where((raw) {
              final role = raw['role'] as String?;
              return role == 'user' || role == 'model';
            })
            .map((raw) {
              final e = raw.cast<String, dynamic>();
              final role = (e['role'] as String?) ?? 'assistant';
              return ChatMessage(
                role: role == 'user' ? MessageRole.user : MessageRole.assistant,
                content: (e['text'] as String?) ?? '',
                status: MessageStatus.complete,
                attachments: _parseAttachments(e['attachments']),
                agentId: e['agent_id'] as String?,
              );
            }),
      );
    _streamingMessage = null;
    _activeToolEvents.clear();
    _pendingAction = null;
    _pendingClarification = null;
    _isWaitingForResponse = false;

    // Reflect who last answered so the affordance + sticky agent_id are correct.
    for (final m in _messages.reversed) {
      if (m.agentId != null) {
        _activeAgentId = m.agentId;
        _selectedAgent = _agentById(m.agentId) ?? _selectedAgent;
        break;
      }
    }
    notifyListeners();
    _emit(const ScrollToBottom());

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
      for (final att in _parseAttachments(
        e['attachments'],
      ).where((a) => a.isEditable)) {
        if (seen.add(att.fileId)) {
          _fetchAndOpenDocument(
            att,
            edits: editsByFileId[att.fileId] ?? const [],
          );
        }
      }
    }
  }

  void _handleDocumentResync(Map<String, dynamic> payload) {
    final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
    final fileId = c['file_id'] as String?;
    if (fileId == null) return;
    final version = (c['version'] as num?)?.toInt() ?? 0;
    final text = c['text'] as String? ?? '';
    // A resync supersedes any pending proposal for this document.
    _pendingProposals.remove(fileId);
    _proposalFromVersions.remove(fileId);
    final existing = _openDocuments[fileId];
    if (existing != null) {
      existing.resetFromResync(text, version);
    } else {
      _openDocuments[fileId] = TextDocument(
        fileId: fileId,
        filename: (c['filename'] as String?) ?? fileId,
        mimeType: (c['mime_type'] as String?) ?? 'text/plain',
        lines: text.split('\n'),
        version: version,
      );
      _activeDocumentFileId ??= fileId;
    }
    notifyListeners();
  }

  void _onSocketError(int gen, Object error) {
    if (gen != _connectionGeneration) return;
    _pendingAudioBytes.clear();
    _audioPlayer.stop();
    _isConnected = false;
    _isWaitingForResponse = false;
    _isInLiveMode = false;
    _connectionError = 'WebSocket error: $error';
    _streamingMessage = null;
    _activeToolEvents.clear();
    notifyListeners();
  }

  void _onSocketDone(int gen) {
    if (gen != _connectionGeneration) return;
    _pendingAudioBytes.clear();
    _isConnected = false;
    _isWaitingForResponse = false;
    _isInLiveMode = false;
    _streamingMessage = null;
    _activeToolEvents.clear();
    notifyListeners();
  }

  // ---- Helpers -------------------------------------------------------------

  void _flushAudio() {
    _audioPlayer.play(
      Uint8List.fromList(_pendingAudioBytes),
      sampleRate: _liveAudioSampleRate,
    );
    _pendingAudioBytes.clear();
  }

  List<Attachment> _parseAttachments(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Attachment.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  void _emit(LiveChatUiEvent event) {
    if (!_uiEvents.isClosed) _uiEvents.add(event);
  }
}
