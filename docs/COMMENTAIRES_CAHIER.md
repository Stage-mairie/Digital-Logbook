# Affichage des commentaires dans le cahier

Le widget `TransmissionCard` est partagé par **Consulter le cahier** (Android) et **Historique** (Web). Le commentaire initial est `content`. Pour un prêt rendu, le commentaire facultatif du retour est `return_comment` (API `returnComment`) ; la carte comporte un encadré séparé « Retour du matériel ». Si celui-ci est vide, elle indique « Aucun commentaire renseigné ».

Pour tester : créer un prêt de démonstration, le marquer comme rendu en indiquant une observation, puis ouvrir la carte sur tablette et Web. Les prêts plus anciens marqués rendus **avant** l'ajout du champ peuvent légitimement ne pas avoir de commentaire : on ne peut pas reconstruire une observation absente.

En cas de divergence, consulter la base via le conteneur Docker (voir [BASE_DE_DONNEES.md](BASE_DE_DONNEES.md)) et vérifier que `return_comment` y est renseigné. Ne jamais utiliser `db:seed-demo` sur une DB contenant de vraies données.
