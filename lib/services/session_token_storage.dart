import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_token_web_stub.dart'
    if (dart.library.html) 'session_token_web.dart' as web;

/// Web: sessionStorage (efface a la fin de la session de navigation).
/// Android: keystore via flutter_secure_storage (persiste entre les lancements).
class SessionTokenStorage {
  static const _key = 'digital_logbook_refresh_token';
  static const _secureStorage = FlutterSecureStorage();

  Future<void> write(String token) async {
    if (kIsWeb) {
      web.writeSessionToken(_key, token);
    } else {
      await _secureStorage.write(key: _key, value: token);
    }
  }

  Future<String?> read() async {
    if (kIsWeb) return web.readSessionToken(_key);
    return _secureStorage.read(key: _key);
  }

  Future<void> delete() async {
    if (kIsWeb) {
      web.deleteSessionToken(_key);
    } else {
      await _secureStorage.delete(key: _key);
    }
  }
}
