# Identité visuelle — Cahier de Transmission

L'application s'affiche désormais sous le nom **Cahier de Transmission**, avec le pictogramme CT (cahier + flèches de circulation) sur Android et sur le Web.

## Fichiers utiles

| Usage | Fichier |
|---|---|
| Source du pictogramme | `assets/images/app_icon_ct.png` |
| Nom visible sous l'application Android | `android/app/src/main/res/values/strings.xml` (référencé par `AndroidManifest.xml`) |
| Anciennes versions Android : densités | `android/app/src/main/res/mipmap-*/ic_launcher.png` |
| Android 8+ : icône adaptative | `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` et `drawable/ic_launcher_foreground.png` |
| Titre de l'onglet et métadonnées Web | `web/index.html` |
| Nom de l'application Web installable | `web/manifest.json` |
| Favicon et icônes PWA | `web/favicon.png`, `web/icons/` |
| Nom interne de l'application Flutter | `lib/main.dart` |

**Ne changez pas** `applicationId`, `namespace` ou le `name:` de `pubspec.yaml` simplement pour renommer l'application visible : ces identifiants techniques restent volontairement inchangés pour préserver les installations, les imports et les données existantes.

Sur l'écran de connexion, seul le logo officiel de Saint-André est affiché (légèrement agrandi), au-dessus du titre « Cahier de Transmission ». L'accueil tablette affiche le titre sans pictogramme. Le pictogramme CT reste utilisé pour l'icône Android, le favicon, les icônes PWA et l'en-tête de l'historique Web.

## Vérification en développement

```powershell
flutter pub get
flutter run -d HA1V8Z0V --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Rappel pour la tablette physique reliée en USB : avant la commande Flutter, exécuter `adb -s HA1V8Z0V reverse tcp:3000 tcp:3000` et vérifier que l'API tourne.

Pour le Web, reconstruire le service après modification des icônes :

```powershell
docker compose up --build web
```

En cas d'ancien logo conservé par le navigateur : rechargement forcé (`Ctrl+Shift+R`), suppression éventuelle des données du site, désinstallation/réinstallation de la PWA si elle était installée.

Pour mettre à jour l'icône Android sur une ancienne installation, reconstruire/réinstaller l'APK. Le lanceur Android peut conserver l'ancienne icône brièvement dans son cache.

## Évolutions futures

Pour une nouvelle icône, mettre à jour **à la fois** la source (`assets/images/app_icon_ct.png`) et ses déclinaisons Android/Web. Les PNG sont inclus au dépôt ; aucune commande supplémentaire de génération d'icônes n'est nécessaire pour ce correctif.
