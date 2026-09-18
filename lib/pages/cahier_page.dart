import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class CahierPage extends StatelessWidget {
  final AuthService auth;

  const CahierPage({
    super.key,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulter le cahier'),
      ),
      body: const Center(
        child: Text(
          'Cahier de transmission',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
