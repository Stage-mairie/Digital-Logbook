# Digital-Logbook

Application de terrain avec authentification Flutter + backend Node.js.

## Fonctionnalités

- Page Login.
- Page Accueil.
- Comptes utilisateurs précréés.
- Backend Node.js / Express.
- Mots de passe protégés par Argon2id.
- Vault utilisateurs chiffré avec AES-256-GCM.
- Session persistante pendant 180 jours.
- Token stocké dans le stockage sécurisé Android.
- Déconnexion manuelle.
- Protection contre le stockage du mot de passe sur la tablette.

---

# Architecture

```text
Digital-Logbook/
│
├── lib/
│   ├── main.dart
│   │
│   ├── pages/
│   │   ├── login_page.dart
│   │   └── home_page.dart
│   │
│   └── services/
│       └── auth_service.dart
│
└── backend/
    │
    ├── src/
    │   ├── server.js
    │   └── create-vault.js
    │
    ├── vault/
    │   └── users.vault.enc
    │
    ├── data/
    │
    ├── package.json
    ├── .env
    ├── .env.example
    └── .gitignore
````

---

# 1. Installation Flutter

Depuis :

```powershell
cd "C:\Users\semalbrouc\Desktop\Digital-Logbook"
```

Puis :

```powershell
flutter pub get
```

---

# 2. Installation du backend

Vérifier que Node.js est installé :

```powershell
node --version
npm --version
```

Ensuite :

```powershell
cd backend
npm install
```

---

# 3. Création du Vault

Toujours dans `backend` :

```powershell
npm run create-vault
```

Cette commande crée :

```text
backend/vault/users.vault.enc
```

Le fichier est chiffré avec AES-256-GCM.

Les mots de passe sont d'abord hashés avec Argon2id.

Ils ne sont donc pas enregistrés en clair dans le vault.

---

# 4. Comptes de test

Le script crée deux comptes :

```text
terrain
Terrain2026!
```

et :

```text
admin
Admin2026!
```

Ces comptes sont uniquement destinés au développement.

Ils doivent être remplacés avant la mise en production.

---

# 5. Démarrer le serveur

Dans :

```text
backend
```

lancer :

```powershell
npm start
```

Le serveur démarre sur :

```text
http://localhost:3000
```

Tester :

```text
http://localhost:3000/health
```

Le serveur doit répondre :

```json
{
  "ok": true,
  "service": "Digital-Logbook Auth"
}
```

---

# 6. Démarrer Flutter

Ouvrir un deuxième PowerShell.

```powershell
cd "C:\Users\semalbrouc\Desktop\Digital-Logbook"
```

Puis :

```powershell
flutter create .
flutter run
```

---

# 7. Adresse backend Android

Dans :

```text
lib/services/auth_service.dart
```

on utilise :

```text
http://10.0.2.2:3000
```

`10.0.2.2` permet à l'émulateur Android de contacter le PC Windows.

Pour une vraie tablette Android, il faudra remplacer cette adresse par l'adresse du serveur accessible sur le réseau.

Exemple :

```text
https://digital-logbook.exemple.fr
```

---

# 8. Connexion pendant 6 mois

Le fonctionnement est prévu pour une utilisation terrain.

Lors de la première connexion :

```text
Utilisateur
    |
    v
Login Flutter
    |
    v
Backend
    |
    v
Vault chiffré
    |
    v
Vérification Argon2id
    |
    v
Token de session
    |
    v
Stockage sécurisé Android
```

La tablette ne sauvegarde pas le mot de passe.

Elle conserve uniquement le token de session dans :

```text
flutter_secure_storage
```

La durée de session est :

```text
180 jours
```

soit environ 6 mois.

Au prochain démarrage :

```text
Application
    |
    v
Token présent ?
    |
    +--- NON ---> Login
    |
    +--- OUI
          |
          v
       Backend
          |
          v
     Session valide ?
          |
       +--+--+
       |     |
      OUI   NON
       |     |
       v     v
    Accueil Login
```

---

# 9. Déconnexion

Le bouton de déconnexion présent sur la page Accueil :

1. révoque la session côté serveur ;
2. supprime le token de la tablette ;
3. renvoie vers la page Login.

---

# 10. Sécurité

Ne jamais mettre :

```text
.env
```

dans Git.

La clé :

```text
VAULT_SECRET
```

doit être protégée.

En production, utiliser de préférence :

* Docker secrets ;
* un gestionnaire de secrets ;
* HTTPS ;
* une politique de révocation des sessions ;
* des comptes utilisateurs réels ;
* des sauvegardes sécurisées.

---

# 11. Important : mode hors-ligne

La session de 180 jours ne signifie pas que l'application possède actuellement un mode hors-ligne complet.

La tablette doit pouvoir contacter le backend pour restaurer ou vérifier la session.

Un vrai mode hors-ligne pourra être ajouté ensuite avec :

* stockage local chiffré ;
* file d'attente des transmissions ;
* synchronisation automatique ;
* résolution des conflits ;
* synchronisation avec PostgreSQL.

---

# 12. NDK Android

Si Flutter indique :

```text
Package 28.2.13676358 not found
```

ouvrir Android Studio :

```text
SDK Manager
    >
SDK Tools
    >
Show Package Details
    >
NDK (Side by side)
```

Installer :

```text
28.2.13676358
```

Le NDK 30 peut rester installé.

---

# 13. Problème U+0000

Le projet précédent contenait des caractères NUL :

```text
U+0000
```

qui provoquaient des erreurs Flutter du type :

```text
The control character U+0000 can only be used
in strings and comments.
```

Le script d'installation nettoie automatiquement les fichiers `.dart`.

---

# 14. Changer la durée

La durée est configurée dans :

```text
backend/.env
```

Actuellement :

```text
SESSION_DAYS=180
```

Exemple pour 90 jours :

```text
SESSION_DAYS=90
```

Exemple pour 1 an :

```text
SESSION_DAYS=365
```

---

# 15. Attention au stockage du Vault

Le fichier :

```text
backend/vault/users.vault.enc
```

est chiffré.

La clé permettant de le déchiffrer se trouve dans :

```text
backend/.env
```

Il est donc important de protéger `.env`.

En production, la clé ne devrait pas être distribuée dans le projet.

---

# Fin

Ordre recommandé pour démarrer :

```powershell
cd "C:\Users\semalbrouc\Desktop\Digital-Logbook\backend"

npm install

npm run create-vault

npm start
```

Puis dans un autre terminal :

```powershell
cd "C:\Users\semalbrouc\Desktop\Digital-Logbook"

flutter pub get

flutter run
```

