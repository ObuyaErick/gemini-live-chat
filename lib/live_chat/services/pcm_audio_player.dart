import 'dart:convert';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

/// Plays raw PCM (s16le, mono) audio chunks produced by live mode. Wraps the
/// bytes in a minimal WAV container and hands them to [AudioPlayer] as a data
/// URI, so no native codec support is required (works on web).
class PcmAudioPlayer {
  AudioPlayer? _player = AudioPlayer();

  /// Extracts the sample rate from a mime type like `audio/pcm;rate=16000`,
  /// defaulting to 16 kHz.
  static int sampleRateFromMime(String mimeType) {
    final m = RegExp(r'rate=(\d+)').firstMatch(mimeType);
    return m != null ? (int.tryParse(m.group(1)!) ?? 16000) : 16000;
  }

  Future<void> play(Uint8List pcm, {int sampleRate = 16000}) async {
    final player = _player;
    if (player == null || pcm.isEmpty) return;
    final wav = _buildWav(pcm, sampleRate: sampleRate);
    final dataUri = 'data:audio/wav;base64,${base64Encode(wav)}';
    try {
      await player.stop();
      await player.setUrl(dataUri);
      await player.play();
    } catch (_) {
      // Best-effort playback; a decode failure should never crash the chat.
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }

  // Wraps raw PCM s16le bytes in a minimal 44-byte WAV header.
  static Uint8List _buildWav(Uint8List pcm, {int sampleRate = 16000}) {
    const numChannels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = pcm.length;

    final hdr = ByteData(44);
    // RIFF chunk
    hdr
      ..setUint8(0, 0x52)
      ..setUint8(1, 0x49)
      ..setUint8(2, 0x46)
      ..setUint8(3, 0x46)
      ..setUint32(4, 36 + dataSize, Endian.little)
      ..setUint8(8, 0x57)
      ..setUint8(9, 0x41)
      ..setUint8(10, 0x56)
      ..setUint8(11, 0x45)
      // fmt  sub-chunk
      ..setUint8(12, 0x66)
      ..setUint8(13, 0x6D)
      ..setUint8(14, 0x74)
      ..setUint8(15, 0x20)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, numChannels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little)
      // data sub-chunk
      ..setUint8(36, 0x64)
      ..setUint8(37, 0x61)
      ..setUint8(38, 0x74)
      ..setUint8(39, 0x61)
      ..setUint32(40, dataSize, Endian.little);

    final out = Uint8List(44 + dataSize);
    out.setAll(0, hdr.buffer.asUint8List());
    out.setAll(44, pcm);
    return out;
  }
}
