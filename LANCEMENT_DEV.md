# Digital Logbook — lancement développement en une commande

Ce projet contient un lanceur Windows qui démarre automatiquement tout l'environnement de développement nécessaire pour une **tablette Android physique**.

## Commande quotidienne

Depuis la racine du projet :

```powershell
.\start-dev.cmd
```

C'est la seule commande nécessaire au quotidien.

Le script effectue, dans l'ordre :

1. vérification de Flutter, Node/npm, ADB et PostgreSQL ;
2. détection automatique des chemins Flutter, Android `platform-tools` et PostgreSQL ;
3. initialisation de PostgreSQL local au premier lancement si `postgres-data` n'existe pas ;
4. démarrage de PostgreSQL s'il est arrêté ;
5. création de la base `digital_logbook` si elle n'existe pas ;
6. `npm install` uniquement si `backend/node_modules` est absent ;
7. `npm run db:init` pour mettre le schéma à jour ;
8. démarrage du backend Node dans un second terminal s'il n'est pas déjà actif ;
9. détection de la tablette Android ;
10. `adb reverse` afin que la tablette puisse joindre le backend du PC ;
11. `flutter pub get` ;
12. `flutter run` sur la tablette physique avec la bonne `API_BASE_URL`.

Architecture obtenue :

```text
Tablette Android physique
        |
        | USB / ADB reverse
        v
http://127.0.0.1:3000
        |
        v
Backend Node / Express
        |
        v
PostgreSQL local
```

## Tablette configurée par défaut

Le lanceur utilise par défaut la tablette actuelle :

```text
Lenovo TB128FU
ID ADB : HA1V8Z0V
```

Si une seule autre tablette Android est connectée, le script l'utilise automatiquement.

Pour forcer un autre appareil :

```powershell
.\start-dev.cmd -DeviceId AUTRE_ID
```

Pour connaître les IDs disponibles :

```powershell
flutter devices
```

## Premier lancement

Le fichier suivant doit exister :

```text
backend/.env
```

Il doit au minimum conserver les secrets d'authentification existants et contenir une configuration PostgreSQL locale semblable à :

```env
NODE_ENV=development
PORT=3000

DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=digital_logbook
DB_USER=postgres
DB_PASSWORD=VOTRE_MOT_DE_PASSE_POSTGRES
DB_SSL=false

# Conserver aussi les valeurs déjà utilisées par le projet :
VAULT_SECRET=...
SESSION_DAYS=180
```

**Ne jamais committer `backend/.env`.**

### PostgreSQL sans droits administrateur

Le lanceur utilise le cluster local :

```text
C:\Users\<utilisateur>\postgres-data
```

S'il n'existe pas encore, il est initialisé automatiquement avec :

```text
locale C
UTF-8
SCRAM-SHA-256
```

Cela évite notamment le problème Windows lié à la locale `French_Réunion.1252` et ne nécessite pas de service Windows PostgreSQL.

## Ajouter les données de démonstration

Le seed est volontairement **optionnel**. Pour initialiser/compléter les fausses données :

```powershell
.\start-dev.cmd -Seed
```

Le seed est rejouable : les UUID fixes empêchent les doublons.

## Ce qu'il ne faut plus lancer manuellement

Pour le développement normal sur la tablette, il n'est plus nécessaire de lancer séparément :

```text
pg_ctl ... start
npm run db:init
npm start
adb reverse tcp:3000 tcp:3000
flutter pub get
flutter run -d HA1V8Z0V --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

`start-dev.cmd` orchestre tout cela.

## Arrêt

`Ctrl+C` dans le terminal principal arrête l'application Flutter.

Le terminal backend reste volontairement ouvert pour permettre de relancer rapidement l'application. Pour arrêter le backend, ferme son terminal ou utilise `Ctrl+C` dedans.

PostgreSQL peut rester actif pendant le développement. Pour l'arrêter manuellement :

```powershell
pg_ctl -D "$env:USERPROFILE\postgres-data" stop
```

## Dépannage rapide

### La tablette n'est pas détectée

```powershell
adb devices
```

Elle doit apparaître avec l'état :

```text
HA1V8Z0V    device
```

Si `unauthorized` apparaît, accepte la demande **Autoriser le débogage USB** sur la tablette.

### ADB n'est pas dans le PATH

Le script essaie automatiquement :

```text
%LOCALAPPDATA%\Android\sdk\platform-tools
```

Si ADB n'y est pas, vérifier dans Android Studio :

```text
SDK Manager > SDK Tools > Android SDK Platform-Tools
```

### PostgreSQL ne démarre pas

Consulter :

```text
C:\Users\<utilisateur>\postgres-data\postgres.log
```

### Backend déjà lancé

Le script teste :

```text
http://127.0.0.1:3000/health
```

S'il répond déjà correctement, aucun second backend n'est lancé.

## Production

Ce lanceur sert uniquement au **développement local**.

En production, la tablette ne doit pas utiliser `adb reverse` ni `127.0.0.1`. Elle doit être compilée avec l'URL du backend central :

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.votre-domaine.fr
```

Voir également `DEPLOYMENT.md` pour l'architecture et le déploiement de production.
