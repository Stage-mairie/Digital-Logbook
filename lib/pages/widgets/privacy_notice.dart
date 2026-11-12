import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Information courte propre a Digital-Logbook, avec un lien vers les
/// mentions legales de la Ville de Saint-Andre.
/// La page municipale ne remplace pas une notice propre a ce traitement.
class PrivacyNotice {
  static final Uri _legalUrl =
      Uri.parse('https://www.saint-andre.re/mentions-legales/');

  static const String _shortNotice =
      'Le nom du bénéficiaire, les informations de remise '
      'et, le cas échéant, le nom et la signature du signataire '
      'sont enregistrés pour assurer le suivi interne du matériel.';

  /// Ouvre seulement le lien externe (clic explicite sur le bouton).
  static Future<void> openLegalPage(BuildContext context) async {
    try {
      final opened = await launchUrl(
        _legalUrl,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Impossible d’ouvrir les mentions légales.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Impossible d’ouvrir les mentions légales.'),
          ),
        );
      }
    }
  }

  /// Affiche d'abord le texte RGPD dans l'application : ne redirige pas.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: Color(0xFF176678)),
            SizedBox(width: 10),
            Expanded(child: Text('Données personnelles')),
          ],
        ),
        content: const SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Digital-Logbook est un outil interne de suivi des dons, '
                  'des prêts et des restitutions de matériel, réservé '
                  'aux utilisateurs habilités.',
                ),
                SizedBox(height: 12),
                Text(_shortNotice),
                SizedBox(height: 12),
                Text(
                  'Pour consulter les informations générales de la Ville '
                  'de Saint-André, utilisez le lien ci-dessous.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF536C73)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => openLegalPage(dialogContext),
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('Mentions légales'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

/// Lien dans la connexion et l'historique : ouvre la fenetre d'information.
class PrivacyNoticeLink extends StatelessWidget {
  final bool compact;
  const PrivacyNoticeLink({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => PrivacyNotice.show(context),
      icon: const Icon(Icons.privacy_tip_outlined, size: 18),
      label: Text(compact
          ? 'Données personnelles'
          : 'Protection des données personnelles'),
    );
  }
}

/// Dans le formulaire : la courte information est visible en permanence.
class PrivacyFormInfo extends StatelessWidget {
  const PrivacyFormInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 17,
                color: Color(0xFF416873),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Données personnelles',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF416873),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      PrivacyNotice._shortNotice,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF536C73),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: TextButton.icon(
              onPressed: () => PrivacyNotice.openLegalPage(context),
              icon: const Icon(Icons.open_in_new, size: 15),
              label: const Text('Consulter les mentions légales'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF176678),
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
