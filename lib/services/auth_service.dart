import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_token_storage.dart';

class AuthService {
  static String get baseUrl => ApiConfig.baseUrl;

  static final SessionTokenStorage storage = SessionTokenStorage();

  Future<bool> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
        'clientType': kIsWeb ? 'web' : 'android',
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

    await storage.write(token);

    return true;
  }

  Future<String?> getSessionToken() {
    return storage.read();
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

    await storage.delete();
  }
}
