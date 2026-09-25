import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  /// URL du backend central.
  ///
  /// En développement, si aucune valeur n'est fournie :
  /// - Web : http://localhost:3000
  /// - émulateur Android : http://10.0.2.2:3000
  ///
  /// En production, API_BASE_URL est obligatoire afin d'éviter qu'un build
  /// release tente de contacter localhost ou l'émulateur.
  ///
  /// Exemples :
  /// flutter run -d edge --dart-define=API_BASE_URL=http://localhost:3000
  /// flutter build web --release \
  ///   --dart-define=API_BASE_URL=https://api.digital-logbook.example.fr
  static String get baseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');

    if (configuredUrl.trim().isNotEmpty) {
      return _normalize(configuredUrl);
    }

    if (kReleaseMode) {
      throw StateError(
        'API_BASE_URL doit être fourni pour un build de production. '
        'Utilisez --dart-define=API_BASE_URL=https://votre-api',
      );
    }

    // Depuis l'émulateur Android, 10.0.2.2 pointe vers le PC hôte.
    // Depuis Flutter Web, le navigateur contacte directement localhost.
    return kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
