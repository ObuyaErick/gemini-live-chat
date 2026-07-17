import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Owns the single `/chat/` WebSocket for a session. Decodes inbound frames to
/// maps and relays them, and encodes outbound payloads. Holds no conversation
/// state and imports no widgets — the [LiveChatProvider] drives it.
///
/// Only one channel is open at a time; [connect] closes any prior channel
/// first. The caller is responsible for guarding against a superseded connect
/// (e.g. a session switch mid-handshake) — see the generation counter in the
/// provider.
class ChatSocketService {
  WebSocketChannel? _channel;

  bool get isConnected => _channel != null;

  /// Opens [url] and streams decoded frames to [onFrame]. Malformed (non-JSON)
  /// frames are dropped silently. [onError]/[onDone] mirror the socket's
  /// lifecycle. Completes once the channel is ready (or throws on failure).
  Future<void> connect({
    required String url,
    required void Function(Map<String, dynamic> frame) onFrame,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {
    await disconnect();
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    channel.stream.listen(
      (raw) {
        final Map<String, dynamic> frame;
        try {
          frame = jsonDecode(raw as String) as Map<String, dynamic>;
        } catch (_) {
          return; // malformed frame — ignore
        }
        debugPrint('--------\n${jsonEncode(frame)}');
        onFrame(frame);
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: false,
    );
    await channel.ready;
  }

  /// Encodes and sends [payload]. Returns false when there is no open channel.
  bool send(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return false;
    channel.sink.add(jsonEncode(payload));
    return true;
  }

  /// Closes the current channel, if any. Safe to call repeatedly.
  Future<void> disconnect() async {
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }
}
