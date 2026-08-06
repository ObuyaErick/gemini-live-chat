import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';
import 'package:webs/live_chat/services/chat_socket_service.dart';
import 'package:webs/live_chat/services/pcm_audio_player.dart';

/// Socket stand-in: captures the provider's frame handler so a test can push
/// server frames without opening a channel.
class _FakeSocket extends ChatSocketService {
  void Function(Map<String, dynamic> frame)? _onFrame;

  @override
  Future<void> connect({
    required String url,
    required void Function(Map<String, dynamic> frame) onFrame,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {
    _onFrame = onFrame;
  }

  @override
  bool send(Map<String, dynamic> payload) => true;

  @override
  Future<void> disconnect() async {}

  void emit(Map<String, dynamic> frame) => _onFrame!(frame);
}

class _SilentAudioPlayer extends PcmAudioPlayer {
  @override
  Future<void> play(Uint8List pcm, {int sampleRate = 16000}) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// Server frames captured from a real live-mode turn (`messages.dev.json`, a
/// HAR export). Replaying the actual capture keeps this test honest about the
/// wire shape rather than a guessed one.
List<Map<String, dynamic>> _capturedServerFrames() {
  final har =
      jsonDecode(File('messages.dev.json').readAsStringSync())
          as Map<String, dynamic>;
  final entries = (har['log'] as Map<String, dynamic>)['entries'] as List;
  return [
    for (final entry in entries)
      for (final msg in (entry['_webSocketMessages'] as List? ?? const []))
        if ((msg as Map)['type'] == 'receive')
          jsonDecode(msg['data'] as String) as Map<String, dynamic>,
  ];
}

void main() {
  // PcmAudioPlayer builds a just_audio AudioPlayer eagerly, which touches
  // platform channels even though this test never plays anything.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSocket socket;
  late LiveChatProvider provider;

  setUp(() async {
    socket = _FakeSocket();
    provider = LiveChatProvider(
      socket: socket,
      audioPlayer: _SilentAudioPlayer(),
    );
    await provider.connect();
  });

  tearDown(() => provider.dispose());

  Map<String, dynamic> outputTranscript(String content, {bool? isDelta}) => {
    'type': 'output_transcript',
    'content': content,
    'is_delta': ?isDelta,
  };

  group('live-mode transcripts', () {
    test(
      'delta chunks fold into one bubble, closed by the full-text frame',
      () {
        socket
          ..emit(outputTranscript('Hello! How', isDelta: true))
          ..emit(outputTranscript('can I', isDelta: true))
          ..emit(outputTranscript('help', isDelta: true));

        expect(provider.messages, hasLength(1));
        expect(provider.messages.single.status, MessageStatus.streaming);
        // Chunks arrive pre-trimmed, so the word break is re-inserted.
        expect(provider.messages.single.content, 'Hello! How can I help');

        socket.emit(outputTranscript('Hello! How can I help you today?'));

        expect(provider.messages, hasLength(1));
        final line = provider.messages.single;
        expect(line.content, 'Hello! How can I help you today?');
        expect(line.status, MessageStatus.complete);
        expect(line.isTranscript, isTrue);
        expect(line.role, MessageRole.assistant);
      },
    );

    test('a new spoken turn starts a new bubble', () {
      socket
        ..emit(outputTranscript('Hello', isDelta: true))
        ..emit(outputTranscript('Hello there', isDelta: false))
        ..emit({'type': 'turn_complete'})
        ..emit(outputTranscript('Anything else?', isDelta: true));

      expect(provider.messages, hasLength(2));
      expect(provider.messages[0].content, 'Hello there');
      expect(provider.messages[1].content, 'Anything else?');
    });

    test('a speaker change closes the open line', () {
      socket
        ..emit(outputTranscript('Go ahead', isDelta: true))
        ..emit({
          'type': 'input_transcript',
          'content': 'Show me',
          'is_delta': true,
        })
        ..emit({
          'type': 'input_transcript',
          'content': 'revenue',
          'is_delta': true,
        });

      expect(provider.messages, hasLength(2));
      expect(provider.messages[0].role, MessageRole.assistant);
      expect(provider.messages[0].content, 'Go ahead');
      expect(provider.messages[0].status, MessageStatus.complete);
      expect(provider.messages[1].role, MessageRole.user);
      expect(provider.messages[1].content, 'Show me revenue');
    });

    test('turn_complete seals a line the server never closed', () {
      socket
        ..emit(outputTranscript('Still talking', isDelta: true))
        ..emit({'type': 'turn_complete'});

      expect(provider.messages.single.status, MessageStatus.complete);
    });

    test('a frame without is_delta stands on its own', () {
      socket
        ..emit(outputTranscript('First line'))
        ..emit(outputTranscript('Second line'));

      expect(provider.messages.map((m) => m.content), [
        'First line',
        'Second line',
      ]);
    });

    test('replaying the captured session yields one transcript bubble', () {
      for (final frame in _capturedServerFrames()) {
        socket.emit(frame);
      }

      final transcripts = provider.messages.where((m) => m.isTranscript);
      expect(transcripts, hasLength(1));
      expect(transcripts.single.content, 'Hello! How can I help you today?');
      expect(transcripts.single.status, MessageStatus.complete);
    });
  });
}
