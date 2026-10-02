import 'package:flutter/material.dart';

import '../models/transmission.dart';
import '../services/auth_service.dart';
import 'cahier_page.dart';
import 'login_page.dart';
import 'nouvelle_transmission_page.dart';

class HomePage extends StatelessWidget {
  final AuthService auth;

  const HomePage({
    super.key,
    required this.auth,
  });

  static const Color primary = Color(0xFF2D9595);
  static const Color blue = Color(0xFF5EA0D9);
  static const Color cyan = Color(0xFF70C1D1);
  static const Color green = Color(0xFF88D8C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Cahier de Transmission',
          style: TextStyle(
            color: Color(0xFF214B55),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actions rapides',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF214B55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enregistrez un don ou un prêt, ou consultez le cahier des 7 derniers jours.',
                    style: TextStyle(
                      color: Color(0xFF62818A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final cardWidth = width >= 650 ? (width - 20) / 2 : width;

                      return Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _ActionCard(
                            width: cardWidth,
                            icon: Icons.card_giftcard_outlined,
                            title: 'Enregistrer un don',
                            subtitle: 'Toner, souris, clavier, ordinateur…',
                            color: primary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NouvelleTransmissionPage(
                                    auth: auth,
                                    type: TransmissionType.don,
                                  ),
                                ),
                              );
                            },
                          ),
                          _ActionCard(
                            width: cardWidth,
                            icon: Icons.handshake_outlined,
                            title: 'Enregistrer un prêt',
                            subtitle: 'Clé, VPJ, chargeur, Airbox…',
                            color: blue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NouvelleTransmissionPage(
                                    auth: auth,
                                    type: TransmissionType.pret,
                                  ),
                                ),
                              );
                            },
                          ),
                          _ActionCard(
                            width: cardWidth,
                            icon: Icons.menu_book_outlined,
                            title: 'Consulter le cahier',
                            subtitle: '7 derniers jours + recherche complète',
                            color: cyan,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CahierPage(auth: auth),
                                ),
                              );
                            },
                          ),
                          _ActionCard(
                            width: cardWidth,
                            icon: Icons.logout_outlined,
                            title: 'Déconnexion',
                            subtitle: 'Fermer la session en cours',
                            color: green,
                            onTap: () async {
                              await auth.logout();

                              if (!context.mounted) return;

                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LoginPage(auth: auth),
                                ),
                                (route) => false,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 160,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: color.withOpacity(0.20),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF214B55),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF78939A),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
