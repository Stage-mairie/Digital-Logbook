# Digital-Logbook — Signature d'accusé de remise (Android et Web)

## Fonctionnement

- Après avoir saisi un **don** ou un **prêt** sur la tablette, l'agent peut saisir le nom du signataire et lui faire signer la zone blanche (doigt ou stylet). Le bouton **Effacer** remet le cadre à zéro.
- La signature est facultative pour conserver un mode de fonctionnement sans capture. Si une signature est tracée, le nom du signataire devient obligatoire. Sans signature, laisser aussi le nom vide.
- L'application ne transmet **que le PNG final**, sans points, vitesse, horodatages des gestes ou pression du stylet.
- PostgreSQL ajoute `signature_png BYTEA`, `signer_name` et `signed_at`. Les anciennes transmissions restent inchangées.
- Les réponses ordinaires de `GET /transmissions` ne contiennent que `hasSignature`, `signerName` et `signedAt`, jamais l'image.
- La carte commune tablette/Web charge l'image séparément depuis `GET /transmissions/:id/signature` via le **jeton de session**, à droite sur grand écran, en dessous sur petit écran.
- La signature **n'est pas incluse** dans les exports CSV/JSON/Excel ; ne pas ajouter `signaturePngBase64` à `HistoryExport`.

## Installation

1. Appliquer le patch uniquement si `git apply --check` réussit sur votre copie locale.
2. Démarrer PostgreSQL (cluster local ou instance serveur selon l'environnement).
3. À la racine du backend : `npm run db:init`, puis redémarrer `npm start`.
4. Pour lancer la tablette physique : `adb -s HA1V8Z0V reverse tcp:3000 tcp:3000`, puis `flutter run -d HA1V8Z0V --dart-define=API_BASE_URL=http://127.0.0.1:3000`.
5. Tester un nouveau don, signer et sauvegarder. Vérifier la présence de l'image sur le cahier et le Web. Tester un ancien don non signé ; il reste lisible sans image.

## Conditions RGPD avant mise en production

L'image d'une signature, reliée à une personne, est une **donnée personnelle**. Cette capture statique ne doit pas être utilisée pour une analyse biométrique ou un mécanisme d'identification de l'utilisateur. Cette fonctionnalité documente **un accusé de réception**, pas une signature électronique qualifiée ni une certification d'identité.

À valider avec le DPO de la collectivité avant activation en production :

1. Finalité exacte, nécessité de la signature et base légale applicable ; ne pas présumer que le consentement du salarié/agent constitue une base adaptée.
2. Mention d'information accessible lors de la saisie : responsable, finalité, base légale, destinataires, durée de conservation, droits et contact DPO. Le court texte dans le formulaire **ne remplace pas** cette notice officielle.
3. Durée de conservation et purge des signatures (y compris sauvegardes), en cohérence avec les règles d'archives publiques.
4. Accès restreint aux seuls rôles habilités : cette version réutilise `requireSession` ; **ajouter le contrôle des rôles** avant activation si tous les utilisateurs authentifiés ne doivent pas voir les signatures.
5. HTTPS en production, protection de la base et de ses sauvegardes, politique d'accès, journalisation proportionnée.

**Sécurité de déploiement :** dans `NODE_ENV=production`, la collecte et la consultation d'images sont **désactivées** sauf avec `ENABLE_SIGNATURES=true` dans le `.env` du backend, après validation. En local (`development`), elles sont disponibles pour tests. Ne jamais stocker les PNG dans Git ou un dossier statique public.

Références : https://www.cnil.fr/fr/RGPD-le-registre-des-activites-de-traitement et https://cnil.fr/fr/passer-laction/les-durees-de-conservation-des-donnees
