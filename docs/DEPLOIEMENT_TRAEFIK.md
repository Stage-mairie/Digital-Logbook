# Déploiement Traefik — comptes partagés terrain/admin

## Préparer le serveur

Prérequis : Docker Engine + Compose v2, réseau Docker `traefik` déjà créé, DNS du domaine vers le serveur, routeur Traefik HTTPS `websecure` fonctionnel et certificat TLS géré par le Traefik du serveur.

```bash
cp .env.production.example .env.production
# Modifier le domaine, deux secrets distincts, DB_PASSWORD et VAULT_SECRET.
chmod 600 .env.production
mkdir -p backend/vault
# Le réseau traefik doit exister (il est fourni par le Traefik du serveur).
docker network inspect traefik
```

Pour générer les secrets (une valeur distincte pour chaque variable) : `openssl rand -hex 32`.

## Créer les deux comptes pour la première fois

**À ne faire que si `backend/vault/users.vault.enc` n'existe pas.** Les mots de passe sont demandés dans le terminal, jamais transmis comme arguments ou affichés en clair. Longueur minimale : 14 caractères.

```bash
docker compose --env-file .env.production -f compose.prod.yaml -f compose.vault.yaml --profile setup run --rm --no-deps vault-setup
sudo chown -R 1000:1000 backend/vault
chmod 700 backend/vault
chmod 600 backend/vault/users.vault.enc
```

Le script crée précisément `terrain` et `admin`. Conserver le fichier chiffré **ET** son `VAULT_SECRET` dans une sauvegarde sécurisée. La commande refuse de remplacer un vault existant par défaut.

**Changement des deux mots de passe :** sauvegarder le vault, arrêter les services, relancer `vault-setup --force` (ajouter `--force` à la fin de la commande). Révoquer les sessions PostgreSQL existantes (`DELETE FROM sessions;`) avant de rouvrir l'accès. Cette opération remplace les deux comptes en même temps ; elle n'est pas conçue pour la rotation indépendante des mots de passe.

## Démarrer

```bash
docker compose --env-file .env.production -f compose.prod.yaml config --quiet
docker compose --env-file .env.production -f compose.prod.yaml up -d --build
docker compose --env-file .env.production -f compose.prod.yaml ps
```

L'interface Web est publiée à `https://<APP_DOMAIN>` via Traefik. L'API et PostgreSQL ne sont pas publiés sur l'hôte. `/api` est redirigé par Nginx au backend. `127.0.0.1:8080` reste accessible uniquement localement pour tests ; changer `WEB_PORT` s'il est déjà occupé.

Les noms `traefik` (réseau), `websecure` (entrypoint) et le TLS doivent être adaptés si la DSI utilise d'autres noms ou un terminateur TLS externe. Ne pas publier en HTTP sans HTTPS.

## Vérifications obligatoires

- Tester une connexion `terrain`, une connexion `admin`, puis des mots de passe incorrects.
- Vérifier le certificat HTTPS, les droits d'accès, les signatures et le fonctionnement Android si utilisé.
- Vérifier sauvegardes et restauration PostgreSQL + vault + secret ; consigner les procédures et la rétention RGPD avec la DSI/DPO.
- Le compte partagé ne permet **pas** d'attribuer une action à une personne précise : faire valider cette limite par la DSI.
- Ne pas lancer le script de génération en production à chaque démarrage.
