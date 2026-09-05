# EmploiBoost 2.2.1 — build 64

## Correctifs après test sur téléphone

- bas de l'écran **Mon parcours** protégé par une zone sûre et une marge de
  défilement supplémentaire ;
- suppression du débordement de 7,4 pixels dans **Admin > Défis** ;
- listes déroulantes adaptées aux petits écrans ;
- objectif **Assistant CIP** désormais mesuré dans les défis ;
- chargement de l'Assistant CIP maintenu même si une des deux sources
  Firestore est momentanément indisponible ;
- règles Firestore complétées pour les requêtes `collectionGroup` de
  l'Assistant (`lessons` et `items`) ;
- anciens reçus et anciens droits Premium inclus dans l'onglet Abonnements ;
- examen blanc contrôlé Premium dans l'interface et à nouveau côté Functions.

## Expérience plus ludique

- nouvel espace **Mon parcours** ;
- 7 niveaux d'expérience et progression XP ;
- mission quotidienne configurable ;
- défis temporaires publiables depuis le téléphone ;
- 17 badges, séries de jours et classement ;
- récompenses reliées aux leçons, quiz et simulations ;
- répétition autorisée avec une récompense réduite pour éviter l'exploitation
  artificielle des XP.

## Super Admin

- onglet **Abonnements** avec identité, forfait, statut et dates Google Play ;
- onglet **Défis** pour publier les missions sans reconstruire l'application ;
- état du service IA et cause du dernier échec ;
- statistiques des abonnés actifs et comptes à surveiller ;
- annonces, images, liens, écrans flash et mises à jour conservés ;
- accès Admin Premium de test conservé sans achat Google Play ;
- correction du débordement vertical de l'écran d'erreur Admin.

## Abonnements et IA

- restauration silencieuse des anciens abonnements à nouveau vérifiée côté
  serveur ;
- statut détaillé enregistré après validation Google Play ;
- prise en charge des notifications Google Play en temps réel via Pub/Sub ;
- topic Pub/Sub nommé `play-billing-rtdn` afin d'éviter le préfixe `goog`
  réservé par Google ;
- quota applicatif remboursé lorsqu'un appel IA échoue ;
- message clair si le crédit OpenAI est épuisé, si la clé est invalide ou si
  le fournisseur est temporairement indisponible.

## Important avant publication

1. remettre les fichiers de signature Android historiques ;
2. ajouter du crédit au compte API OpenAI si le solde est épuisé ;
3. remplacer la clé OpenAI si elle a été visible dans une capture ;
4. déployer les Functions ;
5. construire l'AAB et tester le build 64 dans le canal interne Google Play.

Les missions, défis et communications se publient depuis le téléphone. Une
modification du code ou un nouvel AAB passe toujours par une compilation et
Google Play Console.
