import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class NouvelleTransmissionPage extends StatelessWidget {
  final AuthService auth;

  const NouvelleTransmissionPage({
    super.key,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle transmission'),
      ),
      body: const Center(
        child: Text(
          'Nouvelle transmission',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
