import 'dart:typed_data';

import 'package:webs/live_chat/services/chat_socket_service.dart';
import 'package:webs/live_chat/services/mic_streamer.dart';
import 'package:webs/live_chat/services/pcm_audio_player.dart';

/// Socket stand-in: captures the provider's frame handler so a test can push
/// server frames, and records everything the provider sends back.
class FakeChatSocket extends ChatSocketService {
  void Function(Map<String, dynamic> frame)? _onFrame;

  final List<Map<String, dynamic>> sent = [];

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
  bool send(Map<String, dynamic> payload) {
    sent.add(payload);
    return true;
  }

  @override
  Future<void> disconnect() async {}

  /// Delivers a server frame to the provider.
  void emit(Map<String, dynamic> frame) => _onFrame!(frame);
}

class SilentAudioPlayer extends PcmAudioPlayer {
  final List<Uint8List> played = [];
  int stopCount = 0;

  @override
  Future<void> play(Uint8List pcm, {int sampleRate = 16000}) async {
    played.add(pcm);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  void dispose() {}
}

/// Microphone stand-in — never touches a real device, and lets a test push
/// PCM chunks as if the mic had produced them.
class FakeMicStreamer extends MicStreamer {
  FakeMicStreamer({this.failWith});

  /// When set, [start] throws it instead of opening the device.
  final MicrophoneUnavailableException? failWith;

  int startCount = 0;
  int stopCount = 0;
  bool disposed = false;

  // Retained across stop() so a test can simulate the straggler buffer a real
  // device hands over after capture has been asked to end.
  void Function(Uint8List chunk)? _sink;
  bool _streaming = false;

  @override
  bool get isStreaming => _streaming;

  @override
  Future<void> start({
    required void Function(Uint8List chunk) onChunk,
    void Function(Object error)? onError,
  }) async {
    startCount++;
    final failure = failWith;
    if (failure != null) throw failure;
    _sink = onChunk;
    _streaming = true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _streaming = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
  }

  void emitChunk(List<int> bytes) => _sink!(Uint8List.fromList(bytes));
}
