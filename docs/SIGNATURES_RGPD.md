# Signatures de réception : tablette, Web et RGPD

La fonctionnalité est **disponible dans les deux environnements** : les fichiers `compose.yaml` et `compose.prod.yaml` injectent explicitement `ENABLE_SIGNATURES=true` dans le backend. Il n'y a pas de désactivation automatique des signatures en production dans ce montage Docker.

## Fonctionnement

1. Sur le formulaire **Don** ou **Prêt**, l'agent complète le nom du bénéficiaire/signataire et recueille sa signature au doigt ou au stylet dans le bloc de signature. On peut effacer et recommencer.
2. Le client transmet une **image PNG statique** (max. 300 Ko) et le nom, sans pression/vitesse/trajectoire biométrique.
3. L'API enregistre `signature_png BYTEA`, `signer_name`, `signed_at` dans `transmissions`.
4. Les listes ne renvoient que `hasSignature`, `signerName`, `signedAt` ; l'image est chargée séparément avec authentification depuis `GET /transmissions/:id/signature`.
5. La carte affiche la signature à droite sur grand écran, en dessous sur écran étroit. Les signatures ne sont **pas** exportées dans CSV/JSON/Excel.

## Données personnelles et précautions avant toute mise en service

Une signature reliée au bénéficiaire est une **donnée personnelle**. Ici, il s'agit d'un accusé de réception du matériel, **pas** d'une signature électronique qualifiée ni d'une authentification biométrique. La mise à disposition technique en production n'équivaut pas à une validation RGPD.

À faire valider avec le DPO : finalité/nécessité et base légale, notice d'information (responsable, finalité, destinataires, droits et contact), habilitation par rôle, rétention et archivage public, sauvegardes, journalisation proportionnée et purge éventuelle. Le code actuel protège l'endpoint par `requireSession` mais **tous les comptes authentifiés peuvent potentiellement voir les signatures** ; restreindre par rôle si requis. HTTPS obligatoire en production, aucun accès public direct à la DB ni aux PNG.

Références générales : https://www.cnil.fr/fr/RGPD-le-registre-des-activites-de-traitement et https://www.cnil.fr/fr/les-durees-de-conservation-des-donnees

Pour lancer : [DEV](DEVELOPPEMENT.md) ; [PROD](PRODUCTION.md).
