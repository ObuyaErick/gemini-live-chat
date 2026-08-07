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
import 'package:webs/live_chat/services/mic_streamer.dart';
import 'package:webs/live_chat/services/pcm_audio_player.dart';
import 'package:webs/models/agent_models.dart';

enum ChatMode {
  live,
  standard;

  bool get isLive => this == ChatMode.live;
  bool get isStandard => this == ChatMode.standard;
}

/// The single source of truth for a live-chat surface: the `/chat/` connection,
/// the transcript, tool/action/clarification state, editable documents, live
/// (voice) mode, the agent roster, and the session list.
class LiveChatProvider extends ChangeNotifier {
  LiveChatProvider({
    ChatSocketService? socket,
    PcmAudioPlayer? audioPlayer,
    MicStreamer? micStreamer,
    AgentService? agentService,
  }) : _socket = socket ?? ChatSocketService(),
       _audioPlayer = audioPlayer ?? PcmAudioPlayer(),
       _micStreamer = micStreamer ?? MicStreamer(),
       _agentService = agentService ?? AgentService();

  final ChatSocketService _socket;
  final PcmAudioPlayer _audioPlayer;
  final MicStreamer _micStreamer;
  final AgentService _agentService;
  final StreamController<LiveChatUiEvent> _uiEvents =
      StreamController<LiveChatUiEvent>.broadcast();

  // ---- Agents & connection -------------------------------------------------
  List<Agent> _agents = const [];
  Agent? _selectedAgent;
  ChatContext? _chatContext;

  // Bumped on every (re)connect. Socket callbacks capture the generation they
  // were registered under and ignore events from a superseded channel.
  int _connectionGeneration = 0;
  ChatMode? _chatMode;
  bool _isConnected = false;
  String? _connectionError;
  bool _isWaitingForResponse = false;

  // ---- Conversation --------------------------------------------------------
  final List<ChatMessage> _messages = [];
  final List<ToolEvent> _activeToolEvents = [];
  ChatMessage? _streamingMessage;
  PendingAction? _pendingAction;
  PendingClarification? _pendingClarification;

  // ---- Editable documents --------------------------------------------------
  final Map<String, TextDocument> _openDocuments = {};
  String? _activeDocumentFileId;
  final Map<String, String> _pendingProposals = {};
  final Map<String, String> _pendingOldValues = {};

  // ---- Staged uploads ------------------------------------------------------
  final List<LocalFileAttachment> _stagedFiles = [];

  // ---- Live-mode audio -----------------------------------------------------
  final List<int> _pendingAudioBytes = [];
  int _liveAudioSampleRate = 16000;
  ChatMessage? _transcriptMessage;

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
  String? get activeAgentId => _selectedAgent?.agentId;
  List<SuggestedQuestion> get suggestedQuestions =>
      _selectedAgent?.suggestedQuestions ?? const [];

  bool get isConnected => _isConnected;
  String? get connectionError => _connectionError;
  bool get isWaitingForResponse => _isWaitingForResponse;
  bool get isInLiveMode => _chatMode?.isLive ?? false;

  bool get isMicStreaming => _micStreamer.isStreaming;

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

  void initialize({ChatContext? chatContext}) {
    _chatContext = chatContext;
    loadAgents();
    loadSessions();
    connect();
  }

  /// Fetches the agent roster from `GET /agents`.
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
    _micStreamer.dispose();
    _audioPlayer.dispose();
    _uiEvents.close();
    super.dispose();
  }

  // ---- Connection ----------------------------------------------------------

  Future<void> connect() async {
    final gen = ++_connectionGeneration;
    _connectionError = null;
    _isConnected = false;
    final agentId = _selectedAgent?.agentId ?? 'concierge';
    _selectedAgent ??= _agentById(agentId);
    notifyListeners();

    try {
      final params = <String, String?>{
        'session_id': _currentSessionId,
        'go_auth_token': ApiClient.goAuthToken,
        'token': ApiClient.token,
      }..removeWhere((_, v) => v == null);
      final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final url = '${ApiClient.baseWebsocketUrl}/chat/$agentId?$query';

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
    _stopMicStream();
    _pendingAudioBytes.clear();
    _audioPlayer.stop();
    _isConnected = false;
    _isWaitingForResponse = false;
    _streamingMessage = null;
    _closeTranscript();
    _pendingAction = null;
    _pendingClarification = null;
    _activeToolEvents.clear();
    _openDocuments.clear();
    _activeDocumentFileId = null;
    _pendingProposals.clear();
    _pendingOldValues.clear();
    notifyListeners();
  }

  void _pushContextIfApplicable() {
    final ctx = _chatContext;
    if (ctx == null || _selectedAgent?.isGlobal == true) return;
    _socket.send({'context': ctx.toJson()});
  }

  // ---- Agent / session selection ------------------------------------------

  void switchAgent(Agent agent) {
    if (_selectedAgent?.agentId == agent.agentId) return;
    _selectedAgent = agent;
    _connectionError = null;
    notifyListeners();
  }

  /// Resume an existing shared session.
  void selectSession(ChatSession session) {
    if (_currentSessionId == session.sessionId) return;
    _resetConversationState();
    _currentSessionId = session.sessionId;
    final lastParticipatingAgentId =
        session.participantAgents.lastOrNull ?? session.agentId;
    if (lastParticipatingAgentId != null) {
      _selectedAgent = _agentById(lastParticipatingAgentId) ?? _selectedAgent;
    }
    notifyListeners();
    connect();
  }

  /// Start a fresh conversation with the currently selected agent.
  void newSession() {
    _resetConversationState();
    _currentSessionId = null;
    notifyListeners();
    connect();
  }

  void _resetConversationState() {
    _stopMicStream();
    _messages.clear();
    _activeToolEvents.clear();
    _streamingMessage = null;
    _transcriptMessage = null;
    _pendingAction = null;
    _pendingClarification = null;
    _isWaitingForResponse = false;
    _connectionError = null;
    _openDocuments.clear();
    _activeDocumentFileId = null;
    _pendingProposals.clear();
    _pendingOldValues.clear();
    _stagedFiles.clear();
    _pendingAudioBytes.clear();
  }

  /// Look up a known agent by id. Returns null for a null/unknown id — e.g. a
  /// historical message whose producing agent is no longer in the roster.
  Agent? agentById(String? id) => _agentById(id);

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
        Uri.parse('${ApiClient.baseUrl}/sessions'),
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
    if (trimmed.isEmpty || !_isConnected) return;
    if (isInLiveMode) {
      _sendLiveText(trimmed);
      return;
    }
    if (_isWaitingForResponse) return;

    final files = _stagedFiles.toList();
    _messages.add(
      ChatMessage(
        role: MessageRole.user,
        content: trimmed,
        localAttachments: files,
        agentId: _selectedAgent?.agentId,
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
    if (selectedId != null) {
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

  void _sendLiveText(String trimmed) {
    try {
      if (!_socket.send({'text': trimmed})) {
        throw StateError('no active connection');
      }
    } catch (e) {
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
    if (!_isConnected || isInLiveMode || _isWaitingForResponse) return;
    _socket.send({'type': 'start_live'});
  }

  void endLiveMode() {
    if (!_isConnected || !isInLiveMode) return;
    // Close the mic now rather than waiting for `mode_changed`, so the
    // recording indicator clears the moment the user asks it to.
    _stopMicStream();
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
    _pendingOldValues.remove(fileId);
    if (_activeDocumentFileId == fileId) {
      _activeDocumentFileId = _openDocuments.isEmpty
          ? null
          : _openDocuments.keys.first;
    }
    notifyListeners();
  }

  /// Dismiss the undo banner for an agent edit. The edit is already applied
  /// and committed server-side by the time `text_diff` arrives (guide's
  /// 2026-07-13 deviation from the staged accept/reject design) — there is
  /// nothing to send here, "accept" just clears the affordance.
  void acceptProposal(String fileId) {
    _pendingProposals.remove(fileId);
    _pendingOldValues.remove(fileId);
    notifyListeners();
  }

  /// Undo an already-committed agent edit. Since the change was never staged
  /// server-side, there is no "reject" verb on the wire (§5.4): restore
  /// `old_value` locally and relay that restoration as an ordinary manual
  /// `document_edit`, exactly as if the user had typed it back themselves.
  void rejectProposal(String fileId) {
    final oldValue = _pendingOldValues[fileId];
    final doc = _openDocuments[fileId];
    _pendingProposals.remove(fileId);
    _pendingOldValues.remove(fileId);
    if (oldValue != null && doc != null) {
      final diff = TextDocument.generateDiff(
        doc.filename,
        doc.content,
        oldValue,
      );
      if (diff.isNotEmpty) {
        _sendDocumentEdit(fileId, diff);
        doc.resetFromResync(oldValue, doc.version + 1);
      }
    }
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
        if (toAgentId != null && _selectedAgent?.agentId != toAgentId) {
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
            agentId: _selectedAgent?.agentId,
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

          if (content.isNotEmpty || attachments.isNotEmpty) {
            _messages.add(
              ChatMessage(
                role: MessageRole.assistant,
                content: content,
                status: MessageStatus.complete,
                attachments: attachments,
                agentId: activeAgentId,
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
            agentId: activeAgentId,
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
        _chatMode = mode == 'live' ? ChatMode.live : ChatMode.standard;
        // The mic follows the server's confirmation, not the button press —
        // capturing before the server is in live mode would drop the audio.
        if (mode == 'live') {
          _startMicStream();
        } else {
          _closeTranscript();
          _stopMicStream();
        }
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
        _handleTranscript(payload, MessageRole.assistant);

      case 'input_transcript':
        _handleTranscript(payload, MessageRole.user);

      case 'interrupted':
        _audioPlayer.stop();
        _pendingAudioBytes.clear();
        _closeTranscript();
        notifyListeners();

      case 'turn_complete':
        if (_pendingAudioBytes.isNotEmpty) _flushAudio();
        _closeTranscript();

      case 'executable_code':
      case 'code_execution_result':
        break;

      case 'text_diff':
        final c = (payload['content'] as Map?)?.cast<String, dynamic>() ?? {};
        final fileId = c['file_id'] as String?;
        final doc = fileId == null ? null : _openDocuments[fileId];
        if (doc == null) return;
        final diff = c['diff'] as String? ?? '';
        final toVersion = (c['to_version'] as num?)?.toInt() ?? doc.version;
        final newValue = c['new_value'] as String?;
        final oldValue = c['old_value'] as String?;
        if (newValue != null) {
          doc.resetFromResync(newValue, toVersion);
        } else if (diff.isNotEmpty) {
          doc.applyDiff(
            diff,
            fromVersion: (c['from_version'] as num?)?.toInt() ?? doc.version,
            toVersion: toVersion,
          );
        }
        // Keep the pre-edit body around only so the user can undo — a purely
        // presentational affordance now that the change is already committed.
        if (diff.isNotEmpty && oldValue != null) {
          _pendingProposals[fileId!] = diff;
          _pendingOldValues[fileId] = oldValue;
        }
        _activeDocumentFileId = fileId;
        notifyListeners();

      case 'document_resync':
        _handleDocumentResync(payload);

      case 'error':
        final errMsg = payload['content'] as String? ?? 'Unknown error';
        _streamingMessage?.status = MessageStatus.error;
        _streamingMessage = null;
        _closeTranscript();
        _stopMicStream();
        _activeToolEvents.clear();
        _pendingAction = null;
        _pendingClarification = null;
        _isWaitingForResponse = false;
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

  void _handleTranscript(Map<String, dynamic> payload, MessageRole role) {
    final text = payload['content'] as String? ?? '';
    if (text.isEmpty) return;
    final isDelta = payload['is_delta'] as bool? ?? false;

    var line = _transcriptMessage;
    if (line != null && line.role != role) {
      _closeTranscript();
      line = null;
    }

    if (line == null) {
      line = ChatMessage(
        role: role,
        content: text,
        status: isDelta ? MessageStatus.streaming : MessageStatus.complete,
        isTranscript: true,
        agentId: role == MessageRole.assistant ? activeAgentId : null,
      );
      _messages.add(line);
    } else if (isDelta) {
      line.content = _appendTranscriptChunk(line.content, text);
    } else {
      line.content = text;
      line.status = MessageStatus.complete;
    }

    _transcriptMessage = isDelta ? line : null;
    notifyListeners();
    _emit(const ScrollToBottom());
  }

  void _closeTranscript() {
    _transcriptMessage?.status = MessageStatus.complete;
    _transcriptMessage = null;
  }

  String _appendTranscriptChunk(String buffer, String chunk) {
    if (buffer.isEmpty) return chunk;
    final needsSpace =
        !buffer.endsWith(' ') && !_leadingPunctuation.hasMatch(chunk);
    return needsSpace ? '$buffer $chunk' : buffer + chunk;
  }

  static final _leadingPunctuation = RegExp(r"""^[\s,.!?;:)\]}%…'’"”]""");

  void _handleHistory(Map<String, dynamic> payload) {
    final content =
        (payload['content'] as Map?)?.cast<String, dynamic>() ?? const {};
    final historyAgentId = content['agent_id'] as String?;
    if (historyAgentId != null && historyAgentId != activeAgentId) {
      return;
    }
    final entries = (content['data'] as List?) ?? const [];

    _messages
      ..clear()
      ..addAll(
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
    _transcriptMessage = null;
    _activeToolEvents.clear();
    _pendingAction = null;
    _pendingClarification = null;
    _isWaitingForResponse = false;

    // Reflect who last answered so the affordance + sticky agent_id are correct.
    for (final m in _messages.reversed) {
      if (m.agentId != null) {
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
    _pendingOldValues.remove(fileId);
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
    _connectionError = 'WebSocket error: $error';
    _streamingMessage = null;
    _closeTranscript();
    _stopMicStream();
    _activeToolEvents.clear();
    notifyListeners();
  }

  void _onSocketDone(int gen) {
    if (gen != _connectionGeneration) return;
    _pendingAudioBytes.clear();
    _isConnected = false;
    _isWaitingForResponse = false;
    _streamingMessage = null;
    _closeTranscript();
    _stopMicStream();
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

  /// Opens the mic and streams it to the server for the duration of live mode.
  Future<void> _startMicStream() async {
    final gen = _connectionGeneration;
    try {
      await _micStreamer.start(
        onChunk: _sendAudioChunk,
        onError: (e) => debugPrint('[mic] $e'),
      );
    } on MicrophoneUnavailableException catch (e) {
      if (gen != _connectionGeneration) return;
      _emit(ShowSnackBar('$e', dismissible: true));
      endLiveMode();
      return;
    }
    if (gen != _connectionGeneration || !isInLiveMode) {
      // Live mode ended (or the socket was replaced) while permission was pending
      await _micStreamer.stop();
      return;
    }
    notifyListeners();
  }

  void _stopMicStream() {
    if (!_micStreamer.isStreaming) return;
    _micStreamer.stop();
    notifyListeners();
  }

  void _sendAudioChunk(Uint8List chunk) {
    if (!_isConnected || !isInLiveMode || chunk.isEmpty) return;
    _socket.send({'audio': base64Encode(chunk)});
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
