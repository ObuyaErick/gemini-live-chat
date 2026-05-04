import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webs/api/api_client.dart';
import 'package:webs/auth/auth_config.dart';

class TokenService {
  static const _prefKey = 'auth_token';

  static String generate({
    required String email,
    required String account,
    required String project,
  }) {
    final header = _b64(jsonEncode({'typ': 'JWT', 'alg': 'HS256'}));
    final payload = _b64(jsonEncode({
      'sub': email,
      'account': account,
      'project': project,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    }));
    final signing = '$header.$payload';
    final sigBytes = Hmac(sha256, utf8.encode(AuthConfig.jwtSecret))
        .convert(utf8.encode(signing))
        .bytes;
    final signature = base64Url.encode(sigBytes).replaceAll('=', '');
    return '$signing.$signature';
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, token);
    ApiClient.token = token;
  }

  static Future<void> loadSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      ApiClient.token = saved;
    }
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    ApiClient.token = null;
  }

  static String _b64(String input) =>
      base64Url.encode(utf8.encode(input)).replaceAll('=', '');
}
