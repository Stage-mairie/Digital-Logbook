import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthService {
  static String get baseUrl => ApiConfig.baseUrl;

  static const FlutterSecureStorage storage = FlutterSecureStorage();

  static const String refreshTokenKey = 'digital_logbook_refresh_token';

  Future<bool> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['refreshToken'] as String?;

    if (token == null || token.isEmpty) {
      return false;
    }

    await storage.write(
      key: refreshTokenKey,
      value: token,
    );

    return true;
  }

  Future<String?> getSessionToken() {
    return storage.read(key: refreshTokenKey);
  }

  Future<bool> restoreSession() async {
    final token = await getSessionToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refreshToken': token,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {
      // La session sera revalidee a la prochaine connexion.
    }

    await logout();
    return false;
  }

  Future<void> logout() async {
    final token = await getSessionToken();

    if (token != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'refreshToken': token,
          }),
        );
      } catch (_) {}
    }

    await storage.delete(key: refreshTokenKey);
  }
}
