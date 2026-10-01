# Développement Docker : de zéro au lancement

## Prérequis

- Docker Desktop + Compose v2 **mode Linux containers** (virtualisation/WSL2 si nécessaire, autorisation DSI sur poste géré).
- Git. Pour la tablette : Android Studio, Flutter SDK et `adb` sur **Windows**.
- Le premier build du Web télécharge le SDK Flutter Linux 3.47.5 ; prévoir un accès Internet et plusieurs minutes.

## Première installation (une seule fois)

À la racine du dépôt, dans PowerShell :

```powershell
Copy-Item .env.example .env
notepad .env
New-Item -ItemType Directory -Force backend/vault | Out-Null
```

Remplacez impérativement les placeholders `DB_PASSWORD` et `VAULT_SECRET` par des valeurs de développement privées. Pour générer une valeur : **Si vous venez du démarrage Node local, recopiez la valeur `VAULT_SECRET` de l’ancien `backend/.env` vers le nouveau `.env` de la racine pour continuer à déchiffrer le vault existant.** Le mot de passe de la nouvelle base Docker peut être différent de celui du PostgreSQL Windows.

```powershell
[Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
```

**Vault existant :** conserver `backend/vault/users.vault.enc` et la valeur de `VAULT_SECRET` avec laquelle il a été chiffré. Ne pas le régénérer.

**Si aucun vault n'existe (nouvelle installation DEV uniquement)** :

```powershell
docker compose --profile setup run --rm --no-deps vault-init
```

Ce script crée des utilisateurs **démo** ; changer le provisionnement avant toute production. Il est normal que `docker compose up` refuse le démarrage si le vault est absent ou si le secret est erroné : aucune réinitialisation silencieuse.

## La commande habituelle

```powershell
docker compose up --build
```

Le démarrage attend automatiquement que `db` passe son healthcheck avant de lancer le backend, puis le Web. L'API exécute le schéma SQL idempotent au démarrage.

| Endpoint DEV | Adresse depuis le PC |
|---|---|
| Flutter Web debug | http://localhost:8080 |
| API/health | http://localhost:3000/health |
| PostgreSQL | `db:5432`, interne aux conteneurs, sans port publié |

Si le port hôte 3000 est déjà occupé par un ancien `npm start`, arrêtez cet ancien processus avant de lancer Compose. Idem pour le serveur PostgreSQL Windows si vous avez choisi de publier manuellement son port (ce Compose ne publie pas PostgreSQL).

```powershell
docker compose ps
docker compose logs -f backend
docker compose logs -f web
docker compose down                  # arrête sans effacer les volumes
```

**Ne pas utiliser `docker compose down -v`** : cette option détruirait la base Docker de cet environnement. Pour ajuster les dépendances backend : modifier `backend/package*.json`, puis `docker compose up --build`.

### Hot reload en DEV

Le backend monte `backend/src` et `backend/sql` et utilise `node --watch`. Le Web monte `lib`, `assets` et `web` ; Flutter peut demander un redémarrage de sa session debug si Docker Desktop ne remonte pas les notifications de modification Windows. En cas de doute : `docker compose restart web` (ou `up --build` après changement de dépendances).

### Seed facultatif

```powershell
docker compose exec backend npm run db:seed-demo
```

Ne pas utiliser en production. Vérifiez d'abord le contenu et l'idempotence du seed si vous le relancez.

## Tablette Lenovo TB128FU en USB

L'APK n'est pas créé par Compose. Laissez `docker compose up --build` en marche, puis dans un **second PowerShell Windows** :

```powershell
adb devices
adb -s HA1V8Z0V reverse tcp:3000 tcp:3000
adb -s HA1V8Z0V reverse --list
flutter pub get
flutter run -d HA1V8Z0V --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

L'émulateur Android utilise `http://10.0.2.2:3000` si aucune variable n'est fournie. Un appareil réel sur un autre réseau doit utiliser une API HTTPS accessible, **pas** `127.0.0.1` sans `adb reverse`.

## Vérifications / problèmes fréquents

- `backend unhealthy` : regarder `docker compose logs backend`. Le vault est-il présent ? Le secret est-il le bon ? `db` est-il healthy ?
- `ECONNREFUSED 127.0.0.1:5432` dans Docker : le backend Docker doit utiliser `DB_HOST=db` ; Compose force déjà cette valeur.
- Le Web marche mais pas la tablette : vérifier `adb reverse`, USB, `API_BASE_URL` et le navigateur de la tablette sur `http://127.0.0.1:3000/health`.
- `flutter_secure_storage` sur Web en production nécessite un contexte HTTPS fiable ; DEV sur `localhost` bénéficie du traitement de contexte local.
- Signatures : `ENABLE_SIGNATURES=true` est forcé dans les deux Compose. Tester la capture, la lecture authentifiée et le commentaire de retour.
- Pour reprendre l'ancienne DB locale : suivre [BASE_DE_DONNEES.md](BASE_DE_DONNEES.md) **avant** de remplacer les données.
