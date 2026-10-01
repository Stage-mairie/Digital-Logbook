# Digital-Logbook

Application de gestion des **dons et prêts de matériel** : Flutter Android (tablette) + Flutter Web (consultation) + API Node/Express + PostgreSQL.

## Démarrer en développement avec Docker

Pré-requis : Docker Desktop (moteur Linux et Compose v2), Git. **Flutter et PostgreSQL ne sont plus nécessaires sur le PC pour lancer le Web et l'API** ; Flutter/ADB restent utiles pour développer sur une tablette Android physique.

Première installation :

```powershell
Copy-Item .env.example .env
# Modifier .env : DB_PASSWORD et VAULT_SECRET, sans écraser un secret déjà utilisé pour le vault.
New-Item -ItemType Directory -Force backend/vault | Out-Null
# Uniquement si backend/vault/users.vault.enc n'existe pas : comptes démo DEV.
docker compose --profile setup run --rm --no-deps vault-init
```

Puis, à chaque lancement :

```powershell
docker compose up --build
```

- Interface Web : <http://localhost:8080>
- API : <http://localhost:3000/health>
- PostgreSQL : service `db` interne, données dans un volume Docker persistant.

**Important :** si vous possédez déjà `backend/vault/users.vault.enc`, conservez ce fichier et son `VAULT_SECRET` d'origine : **ne lancez pas `vault-init`**. La base PostgreSQL locale Windows n'est pas migrée automatiquement dans le volume Docker ; procédure détaillée dans la documentation.

## Production

```bash
cp .env.production.example .env.production
# Configurer secrets, domaine HTTPS et vault de production, puis :
docker compose --env-file .env.production -f compose.prod.yaml up -d --build
```

Le Web de production est servi par Nginx sur `127.0.0.1:8080` pour être placé derrière votre reverse proxy HTTPS. L'API et PostgreSQL ne publient aucun port sur Internet. La signature est activée explicitement en DEV **et** en PROD ; conformité RGPD à valider avant mise en service.

## Documentation

| Sujet | Guide |
|---|---|
| Installation, commandes Docker et tablette Lenovo | [docs/DEVELOPPEMENT.md](docs/DEVELOPPEMENT.md) |
| Déploiement et HTTPS | [docs/PRODUCTION.md](docs/PRODUCTION.md) |
| Diagramme d'architecture | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Sauvegarde et migration de l'ancienne DB | [docs/BASE_DE_DONNEES.md](docs/BASE_DE_DONNEES.md) |
| Fonctionnalités dons/prêts, retours et catalogue | [docs/MATERIEL_ET_RETOURS.md](docs/MATERIEL_ET_RETOURS.md) |
| Signature, informations et RGPD | [docs/SIGNATURES_RGPD.md](docs/SIGNATURES_RGPD.md) |
| Export Web CSV/JSON/Excel | [docs/EXPORT_HISTORIQUE.md](docs/EXPORT_HISTORIQUE.md) |
| Historique et commentaires | [docs/COMMENTAIRES_CAHIER.md](docs/COMMENTAIRES_CAHIER.md) |

Ne commitez **jamais** `.env`, `.env.production`, `backend/vault/*.enc`, des sauvegardes ou des signatures réelles. Les comptes générés par `vault-init` sont des **comptes de démonstration**, interdits en production.
