# Déploiement centralisé en production

## Préparation et sécurité

1. Utiliser un serveur Linux administré, Docker Engine/Compose, un domaine interne ou public et un reverse proxy HTTPS (certificat valide). Respecter la politique de sécurité de la collectivité.
2. Préparer un **vault de production** `backend/vault/users.vault.enc` avec de vrais utilisateurs et son `VAULT_SECRET`, différent des comptes de démonstration. Ne pas le mettre dans Git ni dans l'image.
3. Créer `cp .env.production.example .env.production`, puis configurer mots de passe robustes, `VAULT_SECRET`, `CORS_ORIGINS` et `WEB_PORT`. Conserver ces secrets dans un gestionnaire de secrets administré.
4. Valider avec le DPO la collecte et la conservation des signatures ; la fonctionnalité reste activée dans les deux Compose à la demande du projet (`ENABLE_SIGNATURES=true`).
5. Prévoir sauvegardes chiffrées, gestion des accès, restauration testée et supervision.

## Lancement

```bash
mkdir -p backend/vault
# Déposer de manière sécurisée backend/vault/users.vault.enc AVANT le démarrage.
cp .env.production.example .env.production
# Éditer .env.production : ne jamais conserver les placeholders.
docker compose --env-file .env.production -f compose.prod.yaml config --quiet
docker compose --env-file .env.production -f compose.prod.yaml up -d --build
docker compose --env-file .env.production -f compose.prod.yaml ps
```

Le conteneur Nginx est accessible **uniquement** sur `127.0.0.1:${WEB_PORT:-8080}` ; configurer un reverse proxy TLS sur l'hôte pour relayer `https://logbook.example.fr` vers `http://127.0.0.1:8080` (Nginx/Caddy/traefik du serveur). Ne pas publier l'API ni PostgreSQL sur Internet. Nginx Docker route `/api/*` vers Express et sert le Flutter Web compilé. Flutter Web est construit avec `API_BASE_URL=/api`, donc pas de CORS en same-origin.

**Tablette de production** (sur poste de build Flutter équipé du SDK Android) :

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://logbook.example.fr/api
```

L'APK doit joindre la même adresse HTTPS que le navigateur et ne dépend plus d'USB / `adb reverse`. Distribuer et signer les APK selon les pratiques DSI ; remplacer le package `com.example.*` avant diffusion finale.

## Exploitation

```bash
docker compose --env-file .env.production -f compose.prod.yaml logs -f backend
docker compose --env-file .env.production -f compose.prod.yaml up -d --build
docker compose --env-file .env.production -f compose.prod.yaml down
```

Le volume `db_data_prod` est persistant. **Ne jamais exécuter `down -v` sur la production.** Pour un changement de version, effectuer une sauvegarde DB et du vault + secret avant le nouveau `up --build`.

## Sauvegardes PostgreSQL

Exemple sur le serveur (utiliser les noms DB_USER et DB_NAME de `.env.production`) :

```bash
# Exemple en chargeant les variables de production dans l'environnement de l'opérateur.
docker compose --env-file .env.production -f compose.prod.yaml exec -T db \
  sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > digital_logbook_$(date +%F).dump
```

Sauvegarder également le vault chiffré **et** son secret via deux canaux sécurisés. Tester régulièrement la restauration sur un environnement isolé. Les signatures (`BYTEA`) sont contenues dans `pg_dump` et ne doivent pas être exposées dans des exports bureautiques par défaut.

## RGPD et signature

`ENABLE_SIGNATURES=true` dans Compose DEV/PROD : collecte/consultation uniquement via une session authentifiée, image PNG statique et métadonnées en DB. Cela **n'assure pas à lui seul la conformité** : définir finalité, base légale, information préalable, habilitations par rôle, journalisation d'accès, durée de conservation et règles d'archivage public avec le DPO. Détails : [SIGNATURES_RGPD.md](SIGNATURES_RGPD.md).
