import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:webs/live_chat/models/malloy_dashboard.dart';

/// Fetches `kind: "malloy"` dashboard envelopes from their attachment `url`.
///
/// The URL is a short-lived signed link minted by the server on the frame that
/// delivered the attachment; a 403/404 means it expired and the caller should
/// reconnect the socket to get a fresh one (consumer guide §11).
class MalloyService {
  MalloyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Downloads and parses the `malloy.dashboard.v1` envelope at [url].
  ///
  /// Throws [MalloyFetchException] on a non-200 response or a body that isn't
  /// a JSON object.
  Future<MalloyDashboard> fetchDashboard(String url) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url));
    } catch (e) {
      throw MalloyFetchException('Could not reach the dashboard file: $e');
    }
    if (response.statusCode != 200) {
      throw MalloyFetchException(
        response.statusCode == 403 || response.statusCode == 404
            ? 'This dashboard link has expired — reconnect to refresh it.'
            : 'Dashboard fetch failed (HTTP ${response.statusCode}).',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      throw MalloyFetchException('Dashboard payload is not valid JSON: $e');
    }
    if (decoded is! Map) {
      throw MalloyFetchException('Dashboard payload is not a JSON object.');
    }
    return MalloyDashboard.fromJson(decoded.cast<String, dynamic>());
  }
}

/// Raised when a dashboard envelope can't be retrieved or parsed.
class MalloyFetchException implements Exception {
  const MalloyFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}
