# Architecture

```text
DEV (docker compose up --build)
 Navigateur http://localhost:8080 --> Flutter Web debug (web:8080)
                                     | API_BASE_URL=http://localhost:3000
 PC/Android via adb reverse --------> Node/Express (backend:3000)
                                           |
                                           v
                                      PostgreSQL (db:5432)
```

```text
PROD (docker compose --env-file .env.production -f compose.prod.yaml up -d --build)
 Tablette -> HTTPS public/intranet -> reverse proxy TLS -> nginx Web (:80 interne)
 Navigateur Web ----------------------------^                | /api/*
                                                               v
                                                        Node/Express (backend)
                                                               |
                                                        PostgreSQL (db)
```

La tablette native se compile et s'installe **sur le poste développeur**, pas dans un conteneur. Une fois le backend Docker publié sur l'hôte en DEV, utiliser `adb reverse` (tablette USB) puis `--dart-define=API_BASE_URL=http://127.0.0.1:3000`.

## Données et secrets

- `db_data_dev` et `db_data_prod` sont des volumes Docker **distincts**. `docker compose down` les préserve ; `down -v` les **supprime** (à éviter en présence de données).
- `backend/vault/users.vault.enc` est monté **en lecture seule** dans l'API ; sa clé est `VAULT_SECRET`. Aucune copie du vault dans les images Docker.
- `transmissions`, `equipment_catalog`, `sessions` et les **signatures PNG (`BYTEA`)** résident en PostgreSQL. Les signatures sont chargées via un endpoint authentifié, pas dans les exports.
- Le Web PROD utilise une URL relative `/api`, routée par Nginx au backend. L'APK PROD utilise une URL HTTPS complète, par exemple `https://logbook.example.fr/api`.
- `backend/.env` hérité de l'ancien fonctionnement local n'est **pas lu par Docker Compose**. Le fichier racine `.env` ou `.env.production` alimente Compose.
