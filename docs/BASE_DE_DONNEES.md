# PostgreSQL : création, migrations, conservation des données

- Une seule DB centrale par environnement Compose : service `db` en DEV et PROD ; 3 tables principales : `equipment_catalog`, `transmissions`, `sessions`.
- Le schéma `backend/sql/001_schema.sql` est idempotent et exécuté au démarrage de Node. La signature est en `signature_png BYTEA`, `signer_name`, `signed_at`, avec `return_comment` pour les prêts rendus.
- Le service `db` n'expose volontairement **aucun port hôte**. `DB_HOST=db` est injecté au backend par Compose ; n'utilisez pas `127.0.0.1` depuis le conteneur Node.
- Les volumes `db_data_dev` et `db_data_prod` sont **distincts**. L'ancienne DB créée sur votre Windows dans `C:\Users\...\postgres-data` n'est **pas** automatiquement importée dans Docker.

## Migrer la base PostgreSQL Windows existante vers Docker DEV

**Faire cette procédure uniquement pour récupérer vos données déjà enregistrées**. S'assurer que le `DB_USER` de Compose peut créer les objets dans sa base. Depuis PowerShell sur Windows :

```powershell
# 1. Sauvegarder la base Windows avec votre PostgreSQL local (avant de le désinstaller).
New-Item -ItemType Directory -Force backups | Out-Null
pg_dump -h 127.0.0.1 -p 5432 -U postgres -d digital_logbook -Fc -f backups/digital_logbook_local.dump

# 2. Démarrer uniquement la DB Docker (pas encore le backend).
docker compose up -d db

# 3. Copier l'archive dans le conteneur PostgreSQL.
$dbContainer = docker compose ps -q db
docker cp backups/digital_logbook_local.dump "${dbContainer}:/tmp/digital_logbook_local.dump"

# 4. Restaurer dans la DB Docker (BASE CIBLE VIDE uniquement).
docker compose exec -T db sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_restore --no-owner --no-privileges -U "$POSTGRES_USER" -d "$POSTGRES_DB" /tmp/digital_logbook_local.dump'

# 5. Démarrer le reste : migrations additives exécutées automatiquement.
docker compose up -d --build
```

La restauration ne doit pas être effectuée à l'aveugle sur une DB Docker comportant déjà de nouvelles transmissions : fusion des données, conflits et doublons nécessitent une migration contrôlée. La commande présentée suppose une DB cible **vide**.

## Vérifier ou sauvegarder la DB Docker DEV

```powershell
docker compose exec db sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM transmissions;"'
```

Sauvegarde au format custom dans un terminal capable de rediriger un flux binaire (PowerShell 7.4+ ou `cmd.exe` ; sur Windows PowerShell 5.1, privilégier `docker cp` après une sauvegarde créée DANS le conteneur) :

```powershell
docker compose exec db sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc -f /tmp/logbook.dump'
$dbContainer = docker compose ps -q db
docker cp "${dbContainer}:/tmp/logbook.dump" backups/digital_logbook_docker.dump
```

`docker compose down` préserve la base ; `docker compose down -v` la **supprime**. Protéger les sauvegardes : elles contiennent noms, opérations et signatures.
