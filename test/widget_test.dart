
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transmission_numerique/pages/login_page.dart';
import 'package:transmission_numerique/services/auth_service.dart';

// Simule une session non connectée.
// Aucun appel au serveur n'est nécessaire.
class FakeAuthService extends AuthService {
  @override
  Future<bool> restoreSession() async => false;
}

void main() {
  testWidgets('La page de connexion est affichee',
          (WidgetTester tester) async {

        await tester.pumpWidget(
          MaterialApp(
            home: LoginPage(
              auth: FakeAuthService(),
            ),
          ),
        );

        // Laisse la restauration simulée se terminer.
        await tester.pump();
        await tester.pump(
          const Duration(milliseconds: 100),
        );

        // Vérification des éléments de connexion.
        expect(
          find.text('Cahier de Transmission'),
          findsOneWidget,
        );

        expect(
          find.text('Connexion'),
          findsOneWidget,
        );

        expect(
          find.text('Se connecter'),
          findsOneWidget,
        );
      });
}
