# Exporter l'historique (Web)

Cette fonctionnalité est **réservée à la page Historique Web**, après connexion.
Le bouton **Exporter** est placé à droite de la recherche (ou sous celle-ci si
la fenêtre est étroite) et propose trois formats : CSV, JSON, Excel (`.xlsx`).

## Ce qui est exporté

Le bouton exporte **les résultats effectivement chargés dans la page** :
- sans recherche : toutes les transmissions récupérées de PostgreSQL via l'API ;
- avec une recherche : seulement les transmissions correspondantes ;
- si la recherche est en cours, si une erreur est présente ou s'il n'y a aucun
  résultat, le bouton est désactivé.

Les 14 colonnes couvrent : ID, date, don/prêt, matériel, modèle, autre matériel,
quantité, bénéficiaire, commentaire initial, auteur, statut du prêt, date du
retour, agent ayant enregistré le retour, **commentaire au retour**.

- **CSV** : UTF-8 avec BOM et séparateur `;` adapté à Excel en français. Les
  valeurs sont échappées (guillemets, retours à la ligne) et protégées contre
  l'interprétation accidentelle de formules par Excel.
- **JSON** : tableau d'objets avec les clés de l'API (`createdAt`, `loanStatus`,
  `returnComment`, etc.) et des dates ISO 8601 UTC.
- **Excel** : vrai classeur `.xlsx`, feuille `Historique`, première ligne en
  gras et largeurs de colonnes définies. La quantité est numérique.

Tous les fichiers sont générés dans le navigateur de l'utilisateur à partir
**des données déjà chargées via une route authentifiée**. Rien n'est envoyé
à un service d'export tiers ; le fichier est téléchargé localement.

## Installer le patch

Depuis la racine du projet :

```powershell
git apply --check "$env:USERPROFILE\Downloads\Digital-Logbook-export-web.patch"
git apply "$env:USERPROFILE\Downloads\Digital-Logbook-export-web.patch"
flutter pub get
```

Cette modification ajoute la dépendance Flutter `excel: ^4.0.6` ; `flutter pub
get` met à jour `pubspec.lock`. Ajoutez aussi ce fichier au commit. Pas de
migration PostgreSQL, de modification du backend ni de `npm install`.

Démarrer le backend comme d'habitude puis dans un autre terminal :

```powershell
flutter run -d edge --dart-define=API_BASE_URL=http://localhost:3000
```

Test conseillé : sans recherche, exporter en CSV / JSON / Excel ; chercher
« Toner » et réexporter. Dans les trois cas, vérifier le commentaire au retour
et le nombre de lignes (Excel/CSV : une ligne d'en-tête supplémentaire).

**Confidentialité** : ces exports peuvent contenir des informations internes,
y compris noms, bénéficiaires et commentaires. Les conserver dans un espace
approuvé et éviter de les diffuser hors du service.
