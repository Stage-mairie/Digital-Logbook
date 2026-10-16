# Digital Logbook — Gestion des comptes et mots de passe

Ce guide s'adresse à la personne qui administre le déploiement Docker de Digital Logbook.

## Fonctionnement actuel

- Les comptes sont enregistrés dans un coffre chiffré : `users.vault.enc`.
- Les mots de passe ne sont pas stockés en clair : ils sont hachés avec Argon2id.
- `VAULT_SECRET`, défini dans `.env.production`, sert à déchiffrer le coffre. **Le changer sans recréer le coffre empêche l'application de démarrer.**
- Le script `backend/src/create-vault.js` fourni actuellement crée **uniquement deux comptes** : `terrain` et `admin`.
- Il n'existe **pas de commande pour ajouter un compte isolé** avec le script actuel. L'option `--force` **remplace tout le coffre**.
- La version Docker après migration utilise le volume nommé `vault_data` pour `/app/vault`. Le backend doit le monter en lecture seule (`:ro`), et `vault-setup` en lecture/écriture, avec l'utilisateur `1000:1000`.

> Ces instructions supposent que `compose.prod.yaml` et `compose.vault.yaml` ont déjà été adaptés pour utiliser `vault_data`. Si vos fichiers utilisent encore `./backend/vault:/app/vault`, adaptez-les d'abord : le mélange des deux modes peut faire utiliser deux coffres différents.

## 1. Configurer les secrets

À la racine du projet :

```powershell
Copy-Item .env.production.example .env.production
notepad .env.production
```

Définir notamment `DB_PASSWORD`, `VAULT_SECRET` (au moins 32 caractères aléatoires), `APP_DOMAIN`, `WEB_PORT` et `SESSION_DAYS`.

Pour générer un secret aléatoire avec Node.js :

```powershell
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

Utiliser un secret différent pour la base de données et pour le coffre. Ne jamais commiter `.env.production` ni le fichier `users.vault.enc`.

## 2. Créer les deux comptes pour la première fois

Depuis PowerShell, avec Docker Desktop en cours d'exécution :

```powershell
docker compose --env-file .env.production -f compose.prod.yaml -f compose.vault.yaml --profile setup run --rm --no-deps vault-setup
```

Le script demande, dans cet ordre :

1. Mot de passe `terrain` ; confirmation.
2. Mot de passe `admin` ; confirmation.

Chaque mot de passe doit comporter **au moins 14 caractères**. Les identifiants de connexion restent `terrain` et `admin`.

Ne pas ajouter `--force` lors de la première création.

## 3. Changer les mots de passe des deux comptes existants

**Attention : le script remplace le coffre en entier.** Il faut donc fournir un nouveau mot de passe pour **les deux comptes**, même si un seul doit changer.

Arrêter l'application sans effacer les volumes :

```powershell
docker compose --env-file .env.production -f compose.prod.yaml down
```

Faire une sauvegarde sécurisée du coffre existant et du `VAULT_SECRET` avant cette opération. Puis lancer :

```powershell
docker compose --env-file .env.production -f compose.prod.yaml -f compose.vault.yaml --profile setup run --rm --no-deps vault-setup --force
```

Saisir et confirmer les deux nouveaux mots de passe.

### Révoquer les anciennes sessions

Modifier un mot de passe ne déconnecte **pas automatiquement** les sessions encore valides. Il faut les supprimer de PostgreSQL :

```powershell
docker compose --env-file .env.production -f compose.prod.yaml up -d db

docker compose --env-file .env.production -f compose.prod.yaml exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "DELETE FROM sessions;"'
```

Cette opération déconnecte **tous** les utilisateurs, sans supprimer les données métier.

Redémarrer ensuite :

```powershell
docker compose --env-file .env.production -f compose.prod.yaml up -d --build

docker compose --env-file .env.production -f compose.prod.yaml ps
```

Tester les identifiants depuis la page de connexion.

## 4. Ajouter un troisième compte (modification du code nécessaire)

**Ce n'est pas encore pris en charge par le script livré.** Ne pas tenter d'ajouter un utilisateur en modifiant directement `users.vault.enc` : ce fichier est chiffré et authentifié.

Pour un troisième compte, une évolution du script `backend/src/create-vault.js` est nécessaire :

1. Ajouter un identifiant, un nom et un **ID unique et stable** pour le nouvel utilisateur. Exemple : `user-003`, `accueil`, `Compte accueil`.
2. Demander et confirmer son mot de passe avec la même fonction `passwordFor()` (Argon2id).
3. Ajouter cet utilisateur dans le tableau `users` **avant le chiffrement du coffre**, en préservant les IDs de `terrain` (`user-001`) et `admin` (`user-002`).
4. Modifier le message de confirmation du script pour mentionner les trois comptes.
5. Reconstruire l'image utilisée par `vault-setup`, sauvegarder le coffre et relancer la création avec `--force`, en ressaisissant les mots de passe de **tous** les comptes définis dans le script.
6. Révoquer les sessions existantes, redémarrer et tester chaque identifiant.

Exemple de **structure attendue** pour le tableau `users` dans le script (ces variables devront être calculées par `passwordFor()` avant ce tableau) :

```javascript
const terrainHash = await passwordFor('terrain');
const adminHash = await passwordFor('admin');
const accueilHash = await passwordFor('accueil');

const users = [
  { id: 'user-001', identifier: 'terrain', name: 'Compte terrain', passwordHash: terrainHash },
  { id: 'user-002', identifier: 'admin', name: 'Administrateur', passwordHash: adminHash },
  { id: 'user-003', identifier: 'accueil', name: 'Compte accueil', passwordHash: accueilHash }
];
```

Ce bloc est un **exemple de modification**, pas une commande PowerShell à exécuter. Le nouvel identifiant permet une connexion supplémentaire ; **il n'accorde pas automatiquement de nouvelles autorisations**. Si des rôles ou restrictions d'accès sont souhaités, leur contrôle doit être développé et vérifié côté API.

Pour un usage régulier (ajout, désactivation, changement de mot de passe d'un seul compte), prévoir un vrai outil d'administration du coffre plutôt qu'une réinitialisation générale à chaque fois.

## 5. Vérifications utiles

```powershell
# État des conteneurs
docker compose --env-file .env.production -f compose.prod.yaml ps

# Logs du backend (ne pas partager de secrets)
docker compose --env-file .env.production -f compose.prod.yaml logs --tail=100 backend

# Vérifier que le backend peut lire le coffre
docker compose --env-file .env.production -f compose.prod.yaml run --rm --no-deps --entrypoint sh backend -c "test -r /app/vault/users.vault.enc && echo 'Vault accessible'"
```

Erreurs fréquentes :

- `EACCES` : problème de permissions ; le backend `node` (UID 1000) ne peut pas lire le fichier.
- Erreur de déchiffrement : `VAULT_SECRET` différent de celui ayant servi à créer le coffre, ou fichier corrompu.
- `Vault existant : création refusée` : le fichier existe déjà ; `--force` est destructif et nécessite une sauvegarde.
- `Confirmation incorrecte` : les deux saisies du même mot de passe ne correspondent pas.

## 6. Règles pour la production

- Créer les comptes et secrets **sur le serveur de production**, indépendamment des tests locaux.
- Sauvegarder le volume `vault_data`, le volume PostgreSQL et le secret `VAULT_SECRET` en lieu sûr.
- Ne jamais publier les mots de passe, secrets, ou sauvegardes du coffre dans GitHub.
- Ne jamais utiliser `docker compose down -v` pour un simple redémarrage : cette option supprime les volumes.
- Les comptes partagés ne permettent pas d'identifier individuellement quel agent a effectué une opération. Pour une traçabilité nominative, utiliser des comptes individuels.
