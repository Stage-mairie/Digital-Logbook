# Fonctionnalités : matériel, dons, prêts et retours

## Formulaires Android (tablette)

- **Don** : Toner (modèles `E-STUDIO2518A`, `E-STUDIO2515A`, `E-STUDIO6516AC`), Souris, Clavier, Ordinateur, Casque audio TT, Autre (champ de saisie libre).
- **Prêt** : Clé, VPJ, Chargeur ordinateur, Chargeur USB-C, Ordinateur, Airbox, Flybox, Enrouleur, Téléphone (matériel), Autre.
- Champs communs : quantité, bénéficiaire/service, commentaire/observations facultatif, signature de remise facultative et identité du signataire si signée.
- Les bacs de récupération passent pour le moment par `Autre` avec précision de la référence dans les observations.

## Cahier et retours

Sur la tablette, le cahier présente les 7 derniers jours ; la recherche permet d'interroger tout l'historique. Le Web affiche l'historique complet, avec recherche et export. Les prêts non rendus disposent du bouton **Marquer comme rendu** : validation + commentaire de retour facultatif (max. 1 000 caractères) ; la date et l'utilisateur sont enregistrés. La carte distingue le commentaire du prêt et celui du retour, même si le second est vide.

## Backend et catalogue

Le catalogue provient de `equipment_catalog` (PostgreSQL), initialisé de façon idempotente par `backend/sql/001_schema.sql`. Routes :

- `GET /equipment-catalog?type=don|pret`
- `GET /transmissions` ; `GET /transmissions?days=7` ; `GET /transmissions?q=...`
- `POST /transmissions`
- `PATCH /transmissions/:id/return` avec JSON `{ "returnComment": "..." }`
- `GET /transmissions/:id/signature` (authentifiée)

Voir [ARCHITECTURE.md](ARCHITECTURE.md) et [SIGNATURES_RGPD.md](SIGNATURES_RGPD.md).
