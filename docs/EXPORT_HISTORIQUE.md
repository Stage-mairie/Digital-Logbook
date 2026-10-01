# Exporter l'historique — uniquement sur Flutter Web

Une fois connecté sur la page Historique Web, le bouton **Exporter** propose CSV (`.csv`), JSON (`.json`) et Excel (`.xlsx`). Il exporte **la liste effectivement chargée** : historique complet sans recherche, ou résultats du filtre/recherche actif. Pas d'export si la liste est vide, en cours de chargement ou en erreur.

Les données couvrent l'opération, matériel/modèle, quantité, bénéficiaire, observations initiales, auteur, statut du prêt, retour et commentaire de retour. L'image de la signature **n'est pas exportée**. Les fichiers sont générés localement dans le navigateur ; aucun service tiers d'export n'est appelé. CSV utilise UTF-8 avec BOM et séparateur `;` (tableur français), Excel crée un vrai XLSX.

**Confidentialité :** ne diffuser ces fichiers qu'aux personnes habilitées et les stocker selon la politique du service. Démarrage Web : [DEVELOPPEMENT.md](DEVELOPPEMENT.md) ou [PRODUCTION.md](PRODUCTION.md).
