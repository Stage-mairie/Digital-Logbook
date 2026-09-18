import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_page.dart';

class HomePage extends StatelessWidget {

  final AuthService auth;

  const HomePage({
    super.key,
    required this.auth,
  });

  Future<void> _logout(
      BuildContext context) async {

    await auth.logout();

    if (!context.mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LoginPage(auth: auth),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title:
            const Text('Accueil'),

        actions: [

          IconButton(

            tooltip:
                'Se déconnecter',

            icon:
                const Icon(Icons.logout),

            onPressed: () =>
                _logout(context),
          ),
        ],
      ),

      body: const Center(

        child: Text(

          'Bienvenue sur Digital-Logbook !',

          style: TextStyle(

            fontSize: 24,

            fontWeight:
                FontWeight.bold,
          ),

          textAlign:
              TextAlign.center,
        ),
      ),
    );
  }
}
