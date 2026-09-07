import 'package:flutter_test/flutter_test.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';
import 'package:webs/live_chat/services/read_aloud_service.dart';

import 'live_chat_fakes.dart';

/// Covers the confirmation-gate contract (consumer guide §6.4) as it stands
/// after `action_result` landed: settings are the render surface of a
/// confirmation, a repeated gate frame is a redelivery, `action_result`
/// carries the running→outcome lifecycle, `action_cancel` relays a
/// model-facing reason, `action_amend` closes the dialog without executing
/// while the turn continues toward a re-proposal, an `error` frame never ends
/// a turn (`final` is the sole terminator), and `session_named` retitles the
/// thread.
class FakeReadAloud extends ReadAloudService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatSocket socket;
  late LiveChatProvider provider;

  setUp(() async {
    socket = FakeChatSocket();
    provider = LiveChatProvider(
      socket: socket,
      audioPlayer: SilentAudioPlayer(),
      micStreamer: FakeMicStreamer(),
      readAloudService: FakeReadAloud(),
    );
    await provider.connect();
  });

  tearDown(() => provider.dispose());

  Map<String, dynamic> confirmationFrame({
    List<Map<String, dynamic>>? settings,
  }) => {
    'type': 'action_confirmation',
    'content': {
      'tool_name': 'KNOWLEDGE_PUBLISH_BUNDLE_QUICK',
      'summary': "Publishing 'Guide' to the standard destination.",
      'parameters': {
        'nodes': [
          {'file_id': 'f1', 'resource_id': 'demo_node_200'},
        ],
      },
      'settings':
          settings ??
          [
            {
              'key': 'group',
              'label': 'User group',
              'value': '002',
              'display': 'Engineering',
            },
            {
              'key': 'theme_slug',
              'label': 'Theme',
              'value': 'wi',
              'display': 'Default',
            },
          ],
    },
  };

  group('action_confirmation', () {
    test('parses settings in authored order for rendering', () {
      socket.emit(confirmationFrame());
      final action = provider.pendingAction!;
      expect(action.settings.map((s) => s.label), ['User group', 'Theme']);
      expect(action.settings.first.display, 'Engineering');
      // `value` is the executable identifier, kept but never rendered.
      expect(action.settings.first.value, '002');
    });

    test('a redelivered gate replaces the dialog instead of stacking', () {
      socket.emit(confirmationFrame());
      socket.emit(confirmationFrame(settings: []));
      final action = provider.pendingAction!;
      expect(action.toolName, 'KNOWLEDGE_PUBLISH_BUNDLE_QUICK');
      expect(action.settings, isEmpty); // the latest frame is authoritative
    });
  });

  group('action_result', () {
    test('running dismisses the dialog and shows the pending indicator', () {
      socket.emit(confirmationFrame());
      provider.confirmAction();
      expect(provider.pendingAction, isNull);
      expect(socket.sent.last['type'], 'action_confirm');

      socket.emit({
        'type': 'action_result',
        'content': {
          'tool_name': 'KNOWLEDGE_PUBLISH_BUNDLE_QUICK',
          'status': 'running',
          'summary': "Publishing 'Guide' to the standard destination.",
        },
      });
      expect(provider.runningAction, isNotNull);
      expect(provider.runningAction!.isRunning, isTrue);

      socket.emit({
        'type': 'action_result',
        'content': {
          'tool_name': 'KNOWLEDGE_PUBLISH_BUNDLE_QUICK',
          'status': 'ok',
          'result': {'composition_id': 'COMPID-123'},
          'latency_ms': 8420,
        },
      });
      expect(provider.runningAction, isNull);
    });
  });

  group('action_cancel', () {
    test('relays a model-facing reason when given', () {
      socket.emit(confirmationFrame());
      provider.cancelAction(
        reason: 'The user chose to configure this in the composer instead.',
      );
      final frame = socket.sent.last;
      expect(frame['type'], 'action_cancel');
      expect(frame['reason'], contains('composer'));
    });

    test('omits reason for a plain decline (server default applies)', () {
      socket.emit(confirmationFrame());
      provider.cancelAction();
      final frame = socket.sent.last;
      expect(frame['type'], 'action_cancel');
      expect(frame.containsKey('reason'), isFalse);
    });
  });

  group('action_amend', () {
    test('relays the user instruction and dismisses the dialog', () {
      socket.emit(confirmationFrame());
      provider.amendAction(instruction: 'Publish to the Sales group instead.');
      expect(provider.pendingAction, isNull);
      final frame = socket.sent.last;
      expect(frame['type'], 'action_amend');
      expect(frame['tool_name'], 'KNOWLEDGE_PUBLISH_BUNDLE_QUICK');
      expect(frame['instruction'], contains('Sales'));
    });

    test('a bare amend omits instruction (the model asks what to change)', () {
      socket.emit(confirmationFrame());
      provider.amendAction();
      final frame = socket.sent.last;
      expect(frame['type'], 'action_amend');
      expect(frame.containsKey('instruction'), isFalse);
    });

    test('amended is terminal for the dialog but not the turn', () {
      provider.sendMessage('publish this');
      socket.emit(confirmationFrame());
      provider.amendAction(instruction: 'Different group.');

      // Nothing executed — the server acks with a terminal `amended`, never
      // a `running` phase, and the turn keeps going toward a re-proposal.
      socket.emit({
        'type': 'action_result',
        'content': {
          'tool_name': 'KNOWLEDGE_PUBLISH_BUNDLE_QUICK',
          'status': 'amended',
          'reason': 'Different group.',
        },
      });
      expect(provider.runningAction, isNull);
      expect(provider.pendingAction, isNull);
      expect(provider.isWaitingForResponse, isTrue); // only `final` releases

      // The adjusted gate arrives as a fresh confirmation.
      socket.emit(confirmationFrame(settings: []));
      expect(provider.pendingAction, isNotNull);
    });
  });

  group('turn termination', () {
    test('error never ends the turn — final is the sole terminator', () {
      provider.sendMessage('publish this');
      expect(provider.isWaitingForResponse, isTrue);

      // A gate parks the turn; the user types anyway → the server re-sends
      // the gate then explains the refusal. Neither frame may unlock input
      // or tear the gate down.
      socket.emit(confirmationFrame());
      socket.emit({
        'type': 'error',
        'content':
            'This turn is waiting on the prompt above — answer or dismiss it to continue.',
      });
      expect(provider.isWaitingForResponse, isTrue);
      expect(provider.pendingAction, isNotNull);
      expect(provider.messages.last.status, MessageStatus.error);

      provider.confirmAction();
      socket.emit({'type': 'final', 'content': '', 'attachments': []});
      expect(provider.isWaitingForResponse, isFalse);
    });

    test('a bare final ("" content) keeps the streamed deltas', () {
      provider.sendMessage('hi');
      socket.emit({'type': 'delta', 'content': 'Partial answer'});
      socket.emit({'type': 'error', 'content': 'provider blew up'});
      socket.emit({'type': 'final', 'content': '', 'attachments': []});

      expect(provider.isWaitingForResponse, isFalse);
      final assistantTexts = provider.messages
          .where((m) => m.role == MessageRole.assistant)
          .map((m) => m.content);
      expect(assistantTexts, contains('Partial answer'));
    });
  });

  group('session_named', () {
    test('retitles the thread once the server names it', () {
      socket.emit({
        'type': 'session',
        'content': {'session_id': 's1', 'agent_id': 'concierge'},
      });
      expect(provider.sessions['s1']!.displayLabel, isNot('Q3 revenue'));

      socket.emit({
        'type': 'session_named',
        'content': {'session_id': 's1', 'title': 'Q3 revenue'},
      });
      expect(provider.sessions['s1']!.title, 'Q3 revenue');
      expect(provider.sessions['s1']!.displayLabel, 'Q3 revenue');
    });
  });
}
