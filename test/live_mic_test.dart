import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';
import 'package:webs/live_chat/providers/live_chat_ui_event.dart';
import 'package:webs/live_chat/services/mic_streamer.dart';

import 'live_chat_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatSocket socket;
  late FakeMicStreamer mic;
  late LiveChatProvider provider;

  Future<LiveChatProvider> build({FakeMicStreamer? micStreamer}) async {
    socket = FakeChatSocket();
    mic = micStreamer ?? FakeMicStreamer();
    provider = LiveChatProvider(
      socket: socket,
      audioPlayer: SilentAudioPlayer(),
      micStreamer: mic,
    );
    await provider.connect();
    return provider;
  }

  const enterLive = {
    'type': 'mode_changed',
    'content': {'mode': 'live'},
  };
  const exitLive = {
    'type': 'mode_changed',
    'content': {'mode': 'standard'},
  };

  tearDown(() => provider.dispose());

  group('microphone uplink', () {
    test(
      'opens on the server\'s live confirmation, not on the button',
      () async {
        await build();

        provider.startLiveMode();
        expect(mic.startCount, 0, reason: 'waits for mode_changed');
        expect(socket.sent.last, {'type': 'start_live'});

        socket.emit(enterLive);
        await pumpEventQueue();

        expect(mic.isStreaming, isTrue);
        expect(provider.isMicStreaming, isTrue);
      },
    );

    test('streams chunks as base64 audio frames', () async {
      await build();
      socket.emit(enterLive);
      await pumpEventQueue();

      mic.emitChunk([0, 1, 2, 3]);
      mic.emitChunk([4, 5]);

      final audioFrames = socket.sent.where((f) => f.containsKey('audio'));
      expect(audioFrames.map((f) => f['audio']), [
        base64Encode([0, 1, 2, 3]),
        base64Encode([4, 5]),
      ]);
    });

    test('ending live mode closes the mic and tells the server', () async {
      await build();
      socket.emit(enterLive);
      await pumpEventQueue();

      provider.endLiveMode();

      expect(mic.isStreaming, isFalse);
      expect(socket.sent.last, {'end_live': true});

      socket.emit(exitLive);
      await pumpEventQueue();
      expect(mic.isStreaming, isFalse);
    });

    test('a dropped socket closes the mic', () async {
      await build();
      socket.emit(enterLive);
      await pumpEventQueue();

      provider.disconnect();

      expect(mic.isStreaming, isFalse);
    });

    test('a late chunk after live mode ends is not sent', () async {
      await build();
      socket.emit(enterLive);
      await pumpEventQueue();

      final chunkSink = mic;
      socket.emit(exitLive);
      await pumpEventQueue();
      // The device may hand over one more buffer after the mode flipped.
      chunkSink.emitChunk([9, 9]);

      expect(socket.sent.any((f) => f.containsKey('audio')), isFalse);
    });

    test(
      'a refused permission ends live mode and surfaces the reason',
      () async {
        await build(
          micStreamer: FakeMicStreamer(
            failWith: const MicrophoneUnavailableException(
              'Microphone permission denied',
            ),
          ),
        );

        final events = <LiveChatUiEvent>[];
        provider.uiEvents.listen(events.add);

        socket.emit(enterLive);
        await pumpEventQueue();

        expect(mic.isStreaming, isFalse);
        expect(socket.sent.last, {'end_live': true});
        expect(
          events.whereType<ShowSnackBar>().single.message,
          contains('permission denied'),
        );
      },
    );

    test('dispose releases the device', () async {
      await build();
      socket.emit(enterLive);
      await pumpEventQueue();

      provider.dispose();
      await pumpEventQueue();
      expect(mic.disposed, isTrue);

      // tearDown would dispose a second time.
      provider = await build();
    });
  });
}
