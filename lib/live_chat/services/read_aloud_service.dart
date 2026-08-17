import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webs/api/api_client.dart';
import 'package:webs/live_chat/services/pcm_audio_player.dart';

/// Reads arbitrary UI text aloud via `WS /read-aloud/stream` — the streaming
/// TTS endpoint. Independent of the chat session and of live mode.
///
/// The socket speaks the same outbound frame shapes as live chat: a sequence
/// of `audio_output` frames (base64 raw PCM, mono s16le, rate in `mime_type`),
/// then `turn_complete`, then the server closes. Chunks are accumulated and
/// played once complete through the same WAV-wrapping [PcmAudioPlayer] the
/// live mode uses, so no new decoding path is needed.
class ReadAloudService {
  ReadAloudService({PcmAudioPlayer? player})
    : _player = player ?? PcmAudioPlayer();

  final PcmAudioPlayer _player;
  WebSocketChannel? _channel;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  /// Synthesizes and plays [text]. Throws with the server's message when
  /// synthesis fails (empty text, over the server's length limit, provider
  /// error). A second call interrupts the first.
  Future<void> speak(String text) async {
    await stop();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final url =
        '${ApiClient.baseWebsocketUrl}/read-aloud/stream?token=${ApiClient.token}';
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    _speaking = true;

    final bytes = <int>[];
    var sampleRate = 24000;
    final done = Completer<void>();

    channel.stream.listen(
      (raw) {
        final Map<String, dynamic> frame;
        try {
          frame = jsonDecode(raw as String) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        switch (frame['type'] as String?) {
          case 'audio_output':
            final b64 = frame['content'] as String? ?? '';
            if (b64.isEmpty) return;
            sampleRate = PcmAudioPlayer.sampleRateFromMime(
              frame['mime_type'] as String? ?? '',
            );
            bytes.addAll(base64Decode(b64));
          case 'turn_complete':
            if (!done.isCompleted) done.complete();
          case 'error':
            if (!done.isCompleted) {
              done.completeError(
                Exception(frame['content'] as String? ?? 'Speech failed'),
              );
            }
        }
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
      onDone: () {
        // Server closes after turn_complete; a close with no terminal frame
        // still resolves so the caller never hangs.
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: false,
    );

    try {
      await channel.ready;
      channel.sink.add(jsonEncode({'text': trimmed}));
      await done.future;
      if (_channel != channel) return; // superseded by a newer speak()/stop()
      if (bytes.isNotEmpty) {
        await _player.play(Uint8List.fromList(bytes), sampleRate: sampleRate);
      }
    } finally {
      if (_channel == channel) {
        _channel = null;
        _speaking = false;
      }
      unawaited(channel.sink.close());
    }
  }

  /// Stops playback and abandons any in-flight synthesis.
  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    _speaking = false;
    await channel?.sink.close();
    await _player.stop();
  }

  void dispose() {
    stop();
    _player.dispose();
  }
}
