import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:webs/models/agent_models.dart';

void main() {
  group('Agent.fromJson (live /agents shape)', () {
    test('parses an agent with the full live tool-type set', () {
      // A trimmed slice of a real GET /agents response: no is_global/accounts/
      // agent_instructions/data_sources, numeric temperature/display_order, and
      // the newer tool types.
      final json =
          jsonDecode('''
      {
        "agent_id": "concierge",
        "agent_name": "Concierge",
        "agent_subtitle": "Question Classifier",
        "agent_description": "Routes questions.",
        "agent_image_url": null,
        "agent_profile_text": "Classifier.",
        "agent_welcome_message": null,
        "model_id": "gemini-2.5-flash",
        "temperature": 0.5,
        "status": "active",
        "display_order": 0,
        "suggested_questions": [],
        "tools": [
          {"tool_id": "t1", "tool_name": "DOCUMENT_CREATE", "tool_description": "d", "tool_type": "text_create", "tool_requires_confirmation": false, "tool_order": 1, "tool_output": "{}"},
          {"tool_id": "t2", "tool_name": "ASK_USER", "tool_description": "d", "tool_type": "elicit", "tool_requires_confirmation": null, "tool_order": 1},
          {"tool_id": "t3", "tool_name": "DOCUMENT_EDIT", "tool_description": "d", "tool_type": "text_edit", "tool_order": 1},
          {"tool_id": "t4", "tool_name": "generate_charts", "tool_description": "d", "tool_type": "chart_execution", "tool_order": 2},
          {"tool_id": "t5", "tool_name": "MALLOY_ANALYTICS", "tool_description": "d", "tool_type": "malloy_compile", "tool_order": 3},
          {"tool_id": "t6", "tool_name": "SOMETHING_NEW", "tool_description": "d", "tool_type": "brand_new_type", "tool_order": 4}
        ],
        "requires_context": true
      }
      ''')
              as Map<String, dynamic>;

      final agent = Agent.fromJson(json);

      expect(agent.agentId, 'concierge');
      expect(agent.status, AgentStatus.active);
      expect(agent.temperature, 0.5);
      expect(agent.displayOrder, 0);
      // Missing fields fall back to their defaults.
      expect(agent.isGlobal, false);
      expect(agent.accounts, isEmpty);
      expect(agent.dataSources, isEmpty);
      // All known tool types decode; an unmapped one falls back to `unknown`.
      expect(agent.tools.map((t) => t.toolType).toList(), [
        AgentToolType.textCreate,
        AgentToolType.elicit,
        AgentToolType.textEdit,
        AgentToolType.chartExecution,
        AgentToolType.malloyCompile,
        AgentToolType.unknown,
      ]);
    });

    test('unknown status falls back rather than throwing', () {
      final agent = Agent.fromJson({
        'agent_id': 'x',
        'agent_name': 'X',
        'status': 'brand_new_status',
      });
      expect(agent.status, AgentStatus.unknown);
    });
  });
}
