import 'package:flutter/material.dart';
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
      title: 'Cahier de transmission',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D9595),
        ),
      ),
      home: LoginPage(
        auth: AuthService(),
      ),
    );
  }
}