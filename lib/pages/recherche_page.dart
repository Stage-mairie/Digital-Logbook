import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RecherchePage extends StatelessWidget {
  final AuthService auth;

  const RecherchePage({
    super.key,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher'),
      ),
      body: const Center(
        child: Text(
          'Recherche',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
