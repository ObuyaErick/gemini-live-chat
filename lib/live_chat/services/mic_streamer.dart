import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Thrown when the microphone cannot be opened: permission denied, no input
/// device, or a browser refusing capture (getUserMedia needs a secure origin).
class MicrophoneUnavailableException implements Exception {
  const MicrophoneUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Captures the microphone as raw PCM for live (voice) mode.
///
/// Emits mono s16le chunks at [sampleRate] to the `onChunk` callback of
/// [start]. Chunks are sent continuously as they arrive. Server-side
/// voice-activity detection is disabled (push-to-talk only), so the client
/// itself must mark turn boundaries by sending `{"end_turn": true}` — see
/// `LiveChatProvider.endAudioTurn()` — once the user signals they're done
/// speaking. This class only streams audio; it has no opinion on when a turn
/// ends.
///
/// [start] is a no-op while running, [stop] releases the device, and
/// [dispose] tears the recorder down for good. The owner must call [dispose].
class MicStreamer {
  MicStreamer({AudioRecorder? recorder}) : _recorder = recorder;

  /// Input rate the model expects. The plugin resamples on web, so this holds
  /// even when the hardware captures at 44.1/48 kHz.
  static const int sampleRate = 16000;

  /// Samples per chunk — ~128 ms at 16 kHz. Responsive enough for barge-in
  /// without a socket frame per audio quantum.
  static const int _streamBufferSize = 2048;

  // Created lazily: an AudioRecorder reaches for the platform channel as soon
  // as it exists, which a test double replacing this service must not do.
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _subscription;

  /// Whether the microphone is open and emitting chunks.
  bool get isStreaming => _subscription != null;

  /// Opens the microphone and pushes PCM chunks to [onChunk] until [stop].
  ///
  /// [onError] receives mid-stream failures; the subscription survives them,
  /// since one bad chunk shouldn't end the turn.
  ///
  /// Throws [MicrophoneUnavailableException] if the device can't be opened.
  Future<void> start({
    required void Function(Uint8List chunk) onChunk,
    void Function(Object error)? onError,
  }) async {
    if (_subscription != null) return;

    final recorder = _recorder ??= AudioRecorder();

    if (!await recorder.hasPermission()) {
      throw const MicrophoneUnavailableException(
        'Microphone permission denied',
      );
    }

    final Stream<Uint8List> chunks;
    try {
      chunks = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          streamBufferSize: _streamBufferSize,
        ),
      );
    } catch (e) {
      throw MicrophoneUnavailableException('Could not open the microphone: $e');
    }

    _subscription = chunks.listen(
      onChunk,
      onError: onError,
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    try {
      // `cancel` over `stop`: streaming produces no file to finalise.
      await _recorder?.cancel();
    } catch (_) {
      // Best-effort teardown — a recorder that never started throws here.
    }
  }

  /// Releases the recorder. The instance is unusable afterwards.
  Future<void> dispose() async {
    await stop();
    await _recorder?.dispose();
    _recorder = null;
  }
}
