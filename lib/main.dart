import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final auth = AuthService();

  final authenticated = await auth.restoreSession();

  runApp(
    DigitalLogbookApp(
      auth: auth,
      authenticated: authenticated,
    ),
  );
}

class DigitalLogbookApp extends StatelessWidget {
  final AuthService auth;
  final bool authenticated;

  const DigitalLogbookApp({
    super.key,
    required this.auth,
    required this.authenticated,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),

      home: authenticated
          ? HomePage(auth: auth)
          : LoginPage(auth: auth),
    );
  }
}
