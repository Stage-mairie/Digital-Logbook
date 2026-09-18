import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {

  final AuthService auth;

  const LoginPage({
    super.key,
    required this.auth,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final identifierController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  bool obscurePassword = true;

  bool loading = false;

  String? error;

  Future<void> seConnecter() async {

    setState(() {
      loading = true;
      error = null;
    });

    try {

      final success =
          await widget.auth.login(
        identifierController.text.trim(),
        passwordController.text,
      );

      if (!mounted) {
        return;
      }

      if (success) {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HomePage(auth: widget.auth),
          ),
        );

      } else {

        setState(() {
          error =
              'Identifiant ou mot de passe incorrect.';
        });
      }

    } catch (_) {

      if (mounted) {

        setState(() {

          error =
              'Impossible de contacter le serveur.';

        });
      }

    } finally {

      if (mounted) {

        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {

    identifierController.dispose();

    passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title:
            const Text('Digital-Logbook'),
      ),

      body: Padding(

        padding:
            const EdgeInsets.all(24),

        child: Column(

          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [

            const Text(
              'Connexion',

              style: TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            TextField(

              controller:
                  identifierController,

              decoration:
                  const InputDecoration(
                labelText:
                    'Identifiant',

                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            TextField(

              controller:
                  passwordController,

              obscureText:
                  obscurePassword,

              decoration:
                  InputDecoration(

                labelText:
                    'Mot de passe',

                border:
                    const OutlineInputBorder(),

                suffixIcon:
                    IconButton(

                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),

                  onPressed: () {

                    setState(() {

                      obscurePassword =
                          !obscurePassword;

                    });
                  },
                ),
              ),

              onSubmitted: (_) =>
                  seConnecter(),
            ),

            if (error != null) ...[

              const SizedBox(
                height: 12,
              ),

              Text(

                error!,

                textAlign:
                    TextAlign.center,

                style: TextStyle(

                  color:
                      Theme.of(context)
                          .colorScheme
                          .error,
                ),
              ),
            ],

            const SizedBox(
              height: 24,
            ),

            SizedBox(

              width:
                  double.infinity,

              child:
                  ElevatedButton(

                onPressed:
                    loading
                        ? null
                        : seConnecter,

                child: loading

                    ? const SizedBox(

                        width: 20,
                        height: 20,

                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )

                    : const Text(
                        'Se connecter',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
