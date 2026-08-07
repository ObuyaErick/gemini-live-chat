import 'package:flutter_test/flutter_test.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';

import 'live_chat_fakes.dart';

/// Covers a live-mode bug: typing while in voice mode used to send the
/// standard-mode payload shape (`agent_id` included, guide §9.2 forbids it)
/// and optimistically added a plain user bubble — which then duplicated when
/// the server echoed the same text back as `input_transcript`, one bubble
/// with the mic icon and one without.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatSocket socket;
  late SilentAudioPlayer audioPlayer;
  late LiveChatProvider provider;

  const enterLive = {
    'type': 'mode_changed',
    'content': {'mode': 'live'},
  };

  setUp(() async {
    socket = FakeChatSocket();
    audioPlayer = SilentAudioPlayer();
    provider = LiveChatProvider(
      socket: socket,
      audioPlayer: audioPlayer,
      micStreamer: FakeMicStreamer(),
    );
    await provider.connect();
    socket.emit(enterLive);
    await pumpEventQueue();
  });

  tearDown(() => provider.dispose());

  group('typed turns in live mode', () {
    test('sends the bare live-mode shape — no agent_id, no attachments', () {
      provider.sendMessage('hi');

      expect(socket.sent.last, {'text': 'hi'});
    });

    test(
      'does not add a local bubble — only the echoed input_transcript does',
      () {
        provider.sendMessage('hi');
        expect(provider.messages, isEmpty);

        socket.emit({'type': 'input_transcript', 'content': 'hi'});

        expect(provider.messages, hasLength(1));
        expect(provider.messages.single.content, 'hi');
        expect(provider.messages.single.isTranscript, isTrue);
        expect(provider.messages.single.role, MessageRole.user);
      },
    );

    test('is not gated by isWaitingForResponse — barge-in stays possible', () {
      provider.sendMessage('first');
      // A standard-mode turn would now be blocked until `final` arrives; a
      // live-mode turn must not block, since typing over the model is an
      // intentional interrupt (guide §9.2).
      expect(provider.isWaitingForResponse, isFalse);

      provider.sendMessage('second');

      expect(
        socket.sent.where((f) => f['text'] != null).map((f) => f['text']),
        ['first', 'second'],
      );
    });
  });

  group('interrupted (barge-in)', () {
    test('stops playback and discards buffered audio', () async {
      socket.emit({
        'type': 'audio_output',
        'content': 'AAAA',
        'mime_type': 'audio/pcm;rate=16000',
      });

      socket.emit({'type': 'interrupted'});

      expect(audioPlayer.stopCount, 1);

      // The buffered chunk from before the interrupt must not surface later.
      socket.emit({'type': 'turn_complete'});
      expect(audioPlayer.played, isEmpty);
    });

    test('closes an open transcript line', () {
      socket.emit({
        'type': 'output_transcript',
        'content': 'Halfway through',
        'is_delta': true,
      });
      expect(provider.messages.single.status, MessageStatus.streaming);

      socket.emit({'type': 'interrupted'});

      expect(provider.messages.single.status, MessageStatus.complete);
    });
  });
}
