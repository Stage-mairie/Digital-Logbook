import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'pages/home_page.dart';
import 'pages/web/historique_web_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const CahierTransmissionApp());
}

class CahierTransmissionApp extends StatelessWidget {
  const CahierTransmissionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cahier de Transmission',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D9595),
        ),
      ),
      home: _AuthGate(auth: AuthService()),
    );
  }
}

class _AuthGate extends StatefulWidget {
  final AuthService auth;
  const _AuthGate({required this.auth});

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<bool> _restored = widget.auth.restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restored,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == true) {
          return kIsWeb
              ? HistoriqueWebPage(auth: widget.auth)
              : HomePage(auth: widget.auth);
        }
        return LoginPage(auth: widget.auth);
      },
    );
  }
}
