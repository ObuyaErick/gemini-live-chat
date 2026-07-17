import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:webs/api/api_client.dart';
import 'package:webs/models/agent_models.dart';

/// Fetches the agent roster the authenticated account can see.
///
/// Network contract: `GET /agents` with the bearer token in the `x-winp-token`
/// header, returning a JSON array of agent objects. Throws on a non-2xx
/// response or malformed body; callers decide how to fall back.
class AgentService {
  /// Returns all visible agents, sorted by `display_order` (ascending, nulls
  /// last). `coming_soon` agents are included so the UI can badge them.
  Future<List<Agent>> fetchAgents() async {
    final res = await http.get(
      Uri.parse('${ApiClient.baseUrl}/agents'),
      headers: {if (ApiClient.token != null) 'x-winp-token': ApiClient.token!},
    );
    if (res.statusCode != 200) {
      throw Exception(
        'GET /agents ${res.statusCode} ${res.reasonPhrase ?? ''}',
      );
    }
    final agents =
        (jsonDecode(res.body) as List)
            .whereType<Map>()
            .map((m) => Agent.fromJson(m.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) {
            final ao = a.displayOrder ?? 1 << 30;
            final bo = b.displayOrder ?? 1 << 30;
            return ao.compareTo(bo);
          });
    return agents;
  }
}
