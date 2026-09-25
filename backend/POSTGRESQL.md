# PostgreSQL — Digital Logbook

PostgreSQL est la source de vérité pour :

- le catalogue de matériel ;
- les dons et prêts ;
- les statuts de retour des prêts ;
- les sessions d'authentification.

Le vault utilisateurs chiffré reste dans `backend/vault/users.vault.enc` pour le moment.

Pour l'architecture complète développement / production, la configuration du serveur, les builds Flutter et les sauvegardes, consulter :

```text
../DEPLOYMENT.md
```

## Développement local rapide

Créer une base nommée `digital_logbook`, puis copier :

```powershell
Copy-Item .env.development.example .env
```

Adapter les identifiants PostgreSQL et `VAULT_SECRET`, puis :

```powershell
npm install
npm run db:init
npm run db:seed-demo
npm run dev
```

Le seed de démonstration est réservé au développement.

## Catalogue initial

Toners :

- E-STUDIO2518A
- E-STUDIO2515A
- E-STUDIO6516AC

Les bacs de récupération restent pour l'instant dans `Autre`. Ils pourront être ajoutés à `equipment_catalog` quand les références exactes seront définies, sans modification du code Flutter.

## Production

Ne jamais exposer PostgreSQL directement aux tablettes ou au navigateur.

Le flux doit toujours être :

```text
Flutter -> Backend Node.js -> PostgreSQL
```

Voir `DEPLOYMENT.md` pour la procédure complète.
