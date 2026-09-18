import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {

  // ----------------------------------------------------------
  // EMULATEUR ANDROID
  //
  // 10.0.2.2 = PC Windows depuis l'émulateur Android.
  //
  // Pour une vraie tablette :
  // remplacer par l'adresse IP / URL du serveur.
  // ----------------------------------------------------------

  static const String baseUrl =
      'http://10.0.2.2:3000';

  static const FlutterSecureStorage storage =
      FlutterSecureStorage();

  static const String refreshTokenKey =
      'digital_logbook_refresh_token';

  // ----------------------------------------------------------
  // LOGIN
  // ----------------------------------------------------------

  Future<bool> login(
      String identifier,
      String password) async {

    final response =
        await http.post(

      Uri.parse(
          '$baseUrl/auth/login'),

      headers: {
        'Content-Type':
            'application/json',
      },

      body: jsonEncode({

        'identifier':
            identifier,

        'password':
            password,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final token =
        data['refreshToken']
            as String?;

    if (token == null ||
        token.isEmpty) {

      return false;
    }

    // Le mot de passe n'est PAS sauvegardé.
    //
    // Seul le token de session est stocké
    // dans le stockage sécurisé Android.

    await storage.write(
      key: refreshTokenKey,
      value: token,
    );

    return true;
  }

  // ----------------------------------------------------------
  // RESTAURATION DE SESSION
  // ----------------------------------------------------------

  Future<bool> restoreSession() async {

    final token =
        await storage.read(
      key: refreshTokenKey,
    );

    if (token == null ||
        token.isEmpty) {

      return false;
    }

    try {

      final response =
          await http.post(

        Uri.parse(
            '$baseUrl/auth/refresh'),

        headers: {
          'Content-Type':
              'application/json',
        },

        body: jsonEncode({

          'refreshToken':
              token,
        }),
      );

      if (response.statusCode == 200) {

        return true;
      }

    } catch (_) {

      // Serveur inaccessible.
      //
      // On considère ici que la session
      // doit être revalidée par le serveur.
    }

    await logout();

    return false;
  }

  // ----------------------------------------------------------
  // LOGOUT
  // ----------------------------------------------------------

  Future<void> logout() async {

    final token =
        await storage.read(
      key: refreshTokenKey,
    );

    if (token != null) {

      try {

        await http.post(

          Uri.parse(
              '$baseUrl/auth/logout'),

          headers: {
            'Content-Type':
                'application/json',
          },

          body: jsonEncode({

            'refreshToken':
                token,
          }),
        );

      } catch (_) {}
    }

    await storage.delete(
      key: refreshTokenKey,
    );
  }
}
