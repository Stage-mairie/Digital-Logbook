# Digital Logbook — développement et mise en production

Ce document explique clairement la différence entre l'environnement de développement local et l'environnement de production, ainsi que la façon dont les tablettes, le Web, le backend Node.js et PostgreSQL communiquent.

## 1. Architecture retenue

### Développement local

Sur le poste du développeur :

```text
Flutter Web / Android
        |
        v
Backend Node.js local
http://localhost:3000
        |
        v
PostgreSQL local
127.0.0.1:5432
```

L'émulateur Android ne peut pas utiliser `localhost` pour joindre le PC. Il utilise donc automatiquement :

```text
http://10.0.2.2:3000
```

Flutter Web utilise automatiquement :

```text
http://localhost:3000
```

Ces valeurs par défaut ne sont utilisées qu'en mode développement.

### Production

En production, les appareils ne se connectent jamais directement à PostgreSQL.

```text
Tablette Android -----------\
                             \
Navigateur Web ---------------> HTTPS -> Backend Node.js central
                             /               |
Autres tablettes -----------/                v
                                      PostgreSQL central
```

Exemple :

```text
Application / Web
        |
        v
https://api.digital-logbook.example.fr
        |
        v
Backend Node.js sur le serveur
        |
        v
PostgreSQL sur le serveur ou sur un service PostgreSQL managé
```

Toutes les tablettes et tous les navigateurs voient alors le même historique, car ils passent tous par le même backend, qui utilise la même base PostgreSQL.

## 2. Ce qui est partagé par Git et ce qui ne l'est pas

Git contient le code, les scripts SQL et les fichiers d'exemple de configuration.

Git ne doit jamais contenir :

- `backend/.env`
- le mot de passe PostgreSQL
- `VAULT_SECRET`
- `backend/vault/users.vault.enc`
- une copie locale de PostgreSQL
- des sauvegardes de production

Cloner le dépôt sur un autre ordinateur ne clone donc pas la base de données.

En production, un poste cloné ou une application compilée retrouve les données parce qu'il appelle l'API centrale, pas parce que PostgreSQL est copié avec Git.

## 3. Configuration locale du backend

Dans `backend`, copier l'exemple :

```powershell
Copy-Item .env.development.example .env
```

Puis adapter au minimum :

```env
NODE_ENV=development
PORT=3000
VAULT_SECRET=VOTRE_SECRET_EXISTANT
SESSION_DAYS=180

DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=digital_logbook
DB_USER=postgres
DB_PASSWORD=VOTRE_MOT_DE_PASSE
DB_SSL=false
```

En développement, Flutter Web lancé depuis `localhost` est accepté automatiquement par le backend.

Installer les dépendances :

```powershell
cd backend
npm install
```

Initialiser la base :

```powershell
npm run db:init
```

Ajouter les données fictives uniquement en développement :

```powershell
npm run db:seed-demo
```

Démarrer le backend :

```powershell
npm run dev
```

Vérifier :

```text
http://localhost:3000/health
```

La réponse attendue est similaire à :

```json
{
  "ok": true,
  "service": "Digital-Logbook Auth",
  "database": "connected"
}
```

## 4. Lancer Flutter en développement

### Android Emulator

Le projet utilise automatiquement `http://10.0.2.2:3000` en mode debug Android.

```powershell
flutter run -d emulator-5554
```

### Web

Le projet utilise automatiquement `http://localhost:3000` en mode debug Web.

```powershell
flutter run -d edge
```

Il est également possible de forcer une URL :

```powershell
flutter run -d edge --dart-define=API_BASE_URL=http://localhost:3000
```

## 5. Préparer PostgreSQL de production

### Option recommandée si PostgreSQL est sur le même serveur que Node.js

Créer un utilisateur applicatif dédié au lieu d'utiliser `postgres` :

```sql
CREATE USER digital_logbook_app WITH PASSWORD 'MOT_DE_PASSE_TRES_SOLIDE';
CREATE DATABASE digital_logbook OWNER digital_logbook_app;
```

Le backend se connecte ensuite à :

```env
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=digital_logbook
DB_USER=digital_logbook_app
DB_PASSWORD=MOT_DE_PASSE_TRES_SOLIDE
DB_SSL=false
```

Dans cette configuration, le port PostgreSQL `5432` n'a aucune raison d'être exposé publiquement. Seul le backend doit pouvoir y accéder.

### PostgreSQL distant ou managé

Utiliser de préférence :

```env
DATABASE_URL=postgresql://user:password@host:5432/digital_logbook
DB_SSL=true
```

`DB_SSL=true` est généralement nécessaire avec un fournisseur PostgreSQL distant. Suivre néanmoins les paramètres fournis par l'hébergeur.

## 6. Configuration du backend en production

Sur le serveur :

```bash
cd /opt/digital-logbook/backend
cp .env.production.example .env
```

Modifier le fichier `.env` :

```env
NODE_ENV=production
PORT=3000
VAULT_SECRET=UN_SECRET_LONG_ET_ALEATOIRE
SESSION_DAYS=180

CORS_ORIGINS=https://digital-logbook.example.fr

DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=digital_logbook
DB_USER=digital_logbook_app
DB_PASSWORD=MOT_DE_PASSE_TRES_SOLIDE
DB_SSL=false
```

Pour plusieurs frontends Web :

```env
CORS_ORIGINS=https://digital-logbook.example.fr,https://logbook.intranet.example.fr
```

Ne pas mettre `*`.

Installer les dépendances :

```bash
npm ci
```

Initialiser / mettre à jour le schéma :

```bash
npm run db:init
```

Ne pas exécuter `npm run db:seed-demo` sur la base de production.

Le fichier utilisateur chiffré doit également être provisionné sur le serveur :

```text
backend/vault/users.vault.enc
```

Ce fichier n'est volontairement pas versionné dans Git. `VAULT_SECRET` doit correspondre au secret utilisé pour ce vault.

## 7. Sessions centralisées

Les sessions ne sont plus enregistrées dans `data/sessions.json`.

Elles sont stockées dans la table PostgreSQL :

```text
sessions
```

Cela signifie que :

- les connexions sont gérées par la base centrale ;
- plusieurs instances du backend peuvent utiliser les mêmes sessions ;
- un redéploiement du code ne supprime pas les sessions tant que la base est conservée.

Après l'application de ce patch, les anciennes sessions JSON ne sont pas migrées. Les utilisateurs devront simplement se reconnecter une fois.

## 8. URL de l'API dans les builds de production Flutter

En mode `release`, le projet refuse volontairement d'utiliser `localhost` ou `10.0.2.2`.

Il faut obligatoirement fournir l'URL du backend central avec `API_BASE_URL`.

### Web

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.digital-logbook.example.fr
```

Le contenu généré se trouve dans :

```text
build/web
```

### Android APK

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.digital-logbook.example.fr
```

### Android App Bundle

Pour une distribution via un store / MDM :

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.digital-logbook.example.fr
```

Ainsi, une tablette installée n'a besoin ni de PostgreSQL ni de Node.js localement. Elle ne connaît que l'adresse HTTPS du backend.

## 9. Reverse proxy HTTPS

En production, il est recommandé de ne pas exposer directement Node.js sur Internet.

Le schéma devient :

```text
Internet / réseau interne
        |
      HTTPS 443
        |
      Nginx
        |
 http://127.0.0.1:3000
        |
     Node.js
```

Exemple Nginx minimal :

```nginx
server {
    listen 443 ssl http2;
    server_name api.digital-logbook.example.fr;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Configurer ensuite un certificat TLS valide selon l'infrastructure choisie.

## 10. Lancer automatiquement Node.js sur un serveur Linux

Exemple `systemd` :

```ini
[Unit]
Description=Digital Logbook API
After=network.target postgresql.service

[Service]
Type=simple
User=digital-logbook
WorkingDirectory=/opt/digital-logbook/backend
EnvironmentFile=/opt/digital-logbook/backend/.env
ExecStart=/usr/bin/node src/server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Puis :

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now digital-logbook
sudo systemctl status digital-logbook
```

Le nom et le chemin exacts dépendent du serveur de production.

## 11. Sauvegarder PostgreSQL

Une base centrale doit être sauvegardée régulièrement.

Exemple :

```bash
pg_dump -U digital_logbook_app -d digital_logbook -Fc -f digital_logbook.backup
```

Restaurer dans une base vide :

```bash
pg_restore -U digital_logbook_app -d digital_logbook digital_logbook.backup
```

Les sauvegardes doivent être stockées hors du dépôt Git et idéalement hors du serveur principal.

## 12. Déploiement après un `git pull`

Backend :

```bash
git pull
cd backend
npm ci
npm run db:init
sudo systemctl restart digital-logbook
```

Flutter Web : reconstruire avec l'URL de production :

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.digital-logbook.example.fr
```

Pour Android, reconstruire l'APK/App Bundle uniquement lorsque le code mobile change. Les données et le catalogue matériel restent dans PostgreSQL et ne nécessitent pas de republier l'application.

## 13. Résumé

```text
DEV
PC développeur
├── Flutter
├── Node.js
└── PostgreSQL local

PROD
Tablettes / navigateurs
        |
        v
Backend Node.js central
        |
        v
PostgreSQL central
```

Le frontend n'accède jamais directement à PostgreSQL. Git transporte le code. Le serveur PostgreSQL conserve les données.
