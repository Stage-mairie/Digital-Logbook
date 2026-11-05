# Sessions Digital Logbook — Web et APK Android

- Web : jeton dans `sessionStorage`, restaure sur actualisation du meme onglet, generalement supprime quand l'onglet/la fenetre est fermee. Certains navigateurs restaurent la session apres une fermeture/reouverture ou dupliquent le stockage d'un onglet : ce n'est **pas** une garantie de reconnexion a chaque ouverture.
- Android APK : jeton dans `flutter_secure_storage`, restaure au lancement, expiration serveur sous 180 jours.
- Serveur : `WEB_SESSION_HOURS=8` et `ANDROID_SESSION_DAYS=180`. `SESSION_DAYS` est un repli de compatibilite pour Android.

## Limite de securite

`clientType` est fourni par l'application. Un client non approuve peut le falsifier pour demander 180 jours. Cela ne constitue donc **pas** une politique serveur de separation de confiance. Pour garantir des durees differenciees, prevoir une authentification ou un enrôlement des tablettes gerees (MDM / certificat client / identite de terminal verifiee) et des sessions liees au terminal.

Le Web sur HTTP transmet identifiants et jetons **sans chiffrement**. `sessionStorage` ne corrige pas ce risque. Ne pas deployer pour des comptes reels sur HTTP : demander HTTPS a la DSI. Dans les outils de developpement locaux, voir le mot de passe dans le Payload est normal, meme en HTTPS. Il ne doit pas figurer dans la reponse de l'API ou les journaux.

## Tests

1. `node --check backend/src/server.js`
2. `flutter analyze` et `flutter build web --release`
3. Test sur `http://localhost` : connexion, actualisation, fermeture d'onglet, deconnexion.
4. Construire une APK Android et tester connexion, fermeture/reouverture, deconnexion.
5. Verifier les expirations dans la table `sessions` et l'absence de jeton en clair en base.
6. Modifier les variables d'environnement de production, puis recreer **uniquement le backend** pour prendre en compte les nouveaux parametres.

Ne pas executer `docker compose down -v`. Ne pas versionner les `.env.production`, secrets ou coffres.
