import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:webs/api/api_client.dart';
import 'package:webs/live_chat/models.dart';

class LiveChatProvider extends ChangeNotifier {
  final Map<String, ChatSession> _sessions = {};
  String? _currentAgentId;
  String? _currentSessionId;
  bool _loadingSessions = false;
  String? _sessionsError;

  Map<String, ChatSession> get sessions => Map.unmodifiable(_sessions);

  List<ChatSession> get sessionsByDateDesc {
    final list = _sessions.values.toList()
      ..sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    return list;
  }

  String? get currentAgentId => _currentAgentId;
  String? get currentSessionId => _currentSessionId;
  bool get loadingSessions => _loadingSessions;
  String? get sessionsError => _sessionsError;

  Future<void> loadSessions(String agentId) async {
    _currentAgentId = agentId;
    _loadingSessions = true;
    _sessionsError = null;
    notifyListeners();
    try {
      final url = Uri.parse('${ApiClient.baseUrl}/agents/$agentId/threads');
      final res = await http.get(
        url,
        headers: {if (ApiClient.token != null) 'x-winp-token': ApiClient.token!},
      );
      if (res.statusCode != 200) {
        throw Exception('${res.statusCode} ${res.reasonPhrase ?? ''}');
      }
      final decoded = jsonDecode(res.body);
      final list = (decoded as List).whereType<Map>().toList();
      _sessions.clear();
      for (final m in list) {
        final session = ChatSession.fromJson(m.cast<String, dynamic>());
        _sessions[session.sessionId] = session;
      }
      _loadingSessions = false;
    } catch (e) {
      _loadingSessions = false;
      _sessionsError = 'Failed to load sessions: $e';
    }
    notifyListeners();
  }

  void updateCurrentSessionPreview(String preview) {
    if (_currentSessionId == null) return;
    final session = _sessions[_currentSessionId!];
    if (session == null) return;
    _sessions[_currentSessionId!] = session.copyWith(preview: preview);
    notifyListeners();
  }

  void selectSession(String? sessionId) {
    if (_currentSessionId == sessionId) return;
    _currentSessionId = sessionId;
    notifyListeners();
  }

  void clearCurrentSession() => selectSession(null);

  void registerSessionFromServer(Map<String, dynamic> content) {
    final session = ChatSession.fromJson(content);
    final cachedSession = _sessions[session.sessionId];
    if (cachedSession == null) {
      _sessions[session.sessionId] = session.copyWith(preview: "NEW");
    }
    _currentSessionId = session.sessionId;
    notifyListeners();
  }
}
