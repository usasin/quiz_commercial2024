# EmploiBoost 2.4.0 — entraînement IA maîtrisé

Version Flutter : `2.4.0+67`

## Parcours plus lisible

- suppression des répétitions du titre et de la description du diplôme ;
- sélecteur horizontal compact, prêt à accueillir d’autres parcours ;
- résumé unique du parcours actif avec progression générale ;
- accès aux premiers chapitres beaucoup plus rapide sur petit écran ;
- barre supérieure allégée, avec la déconnexion conservée dans Profil.

## Expérience utilisateur

- 1 simulation découverte gratuite de 5 échanges maximum.
- Premium : 2 simulations guidées par jour, jusqu’à 10 échanges chacune.
- Premium : 1 examen blanc complet inclus tous les 7 jours.
- Pass entraînement intensif : 1 examen blanc supplémentaire, sans abonnement
  supplémentaire.
- Les messages de fin de séance recommandent une révision ciblée et ne parlent
  jamais de jetons ni de coût technique.
- Les mentions « illimité » ont été retirées afin que la promesse corresponde
  exactement au service fourni.

## Sécurité et maîtrise des coûts

- Chaque séance est créée et signée par Firebase Functions.
- Les droits, les compteurs et les Pass sont vérifiés côté serveur dans une
  transaction Firestore.
- Un reçu Google Play ne peut être livré qu’une fois.
- Un Pass n’est consommé qu’au démarrage d’un examen blanc.
- L’historique envoyé à la réponse du personnage est limité aux 8 derniers
  messages au lieu de 40.
- La réponse du personnage est plafonnée à 200 jetons de sortie.
- Une réponse vocale dure au maximum 60 secondes en entraînement et 90 secondes
  en examen.
- La lecture vocale reste locale avec `flutter_tts` et ne consomme pas l’API
  OpenAI.
- Les anciennes versions de l’application restent compatibles, avec un plafond
  serveur journalier plus strict.

## Super Admin

- Compteurs des séances guidées et examens blancs.
- Nombre de Pass intensifs vendus et recette brute estimée.
- Affichage du nombre de Pass disponibles pour chaque utilisateur.
- Plafond de test Admin : 10 séances guidées et 10 examens par jour.

## Produit Google Play attendu

Identifiant exact : `intensive_exam_pass`

Type : produit ponctuel consommable, option d’achat **Acheter**, prix de base
souhaité `0,99 €`, sans renouvellement automatique.
