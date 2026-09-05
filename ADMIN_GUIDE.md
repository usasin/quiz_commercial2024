# Activer et utiliser le Super Admin

## 1. Déployer les fonctions Admin

Depuis `C:\dev\emploiboost` :

```powershell
cd functions
npm ci
npm run lint
cd ..
firebase deploy --only functions --project emploiboost
```

Ce déploiement ajoute les statistiques, la liste des utilisateurs, les accès
Premium de test, les défis, le diagnostic IA et la publication des
communications. Il ne modifie aucun abonnement Google Play existant.

## 2. Donner le rôle Admin à votre compte

1. Ouvrir Firebase Console > **Firestore Database** > `users`.
2. Ouvrir le document qui porte votre UID Firebase.
3. Ajouter un champ de type **boolean** :

```text
admin = true
```

`isAdmin = true` fonctionne également. Un seul des deux champs suffit.

Déconnectez-vous puis reconnectez-vous dans l'application. Dans **Profil**, le
bouton **Super Admin** apparaît automatiquement.

## 3. Tester l'application gratuitement

Dans **Super Admin > Tests** :

- choisissez **Premium** pour ouvrir toutes les fonctions sans achat ;
- choisissez **Gratuit** pour vérifier les limites et les paywalls ;
- réinitialisez les crédits et quotas autant de fois que nécessaire.

Le serveur reconnaît aussi votre rôle Admin pour les simulations IA et
l'examen blanc. Aucune commande Google Play n'est créée.

## 4. Suivre l'application

Dans **Vue générale** :

- nombre d'inscrits ;
- droits Premium enregistrés ;
- abonnements mensuels et annuels ;
- nouveaux inscrits sur 7 et 30 jours ;
- appels IA du jour et du mois ;
- état réel du service IA et cause du dernier échec ;
- abonnés Google Play actifs, résiliés en fin de période ou en incident de
  paiement ;
- revenu mensuel brut estimé.

L'estimation ne déduit pas les commissions, remboursements ou taxes Google.

Dans **Utilisateurs**, recherchez un compte par nom, email ou UID. L'option
**Premium de test** est indépendante d'un vrai abonnement Google Play.

Dans **Abonnements**, vous voyez le nom, l'email, le forfait, le statut, la
date de début, la fin de période et la dernière vérification. Un ancien
abonnement est rapproché de son compte lorsque l'utilisateur ouvre la V2.2 ou
utilise **Restaurer mes achats**. Le chiffre d'affaires comptable exact reste
celui de Google Play Console, car il inclut taxes, remboursements et commission.

## 5. Rendre l'application ludique depuis le téléphone

Dans **Défis** :

1. réglez la mission quotidienne et son bonus XP ;
2. activez un défi spécial ;
3. choisissez quiz, simulations, leçons ou XP ;
4. indiquez l'objectif, la récompense et la durée ;
5. publiez.

Les utilisateurs disposent d'un espace **Mon parcours** avec niveaux, XP,
série de jours, mission quotidienne, défi spécial, badges et classement. Ces
réglages sont publiés depuis l'Admin sans reconstruire l'application.

## 6. Publier une annonce ou une mise à jour

Dans **Communication** :

1. choisissez annonce, mise à jour ou maintenance ;
2. choisissez bannière, fenêtre ou plein écran ;
3. ciblez tous les utilisateurs, les gratuits ou les Premium ;
4. ajoutez titre, message, lien d'image et bouton ;
5. choisissez la durée ;
6. publiez.

Pour une mise à jour obligatoire, indiquez :

- le lien Play Store ;
- le build minimum accepté ;
- **Mise à jour obligatoire** activée.

L'écran bloquant ne s'affiche que sur les versions dont le build est inférieur
au minimum. La version de ce paquet est `2.2.1+64`.

Depuis le téléphone, cet espace permet de publier immédiatement une annonce,
une image, un lien, une maintenance ou un écran demandant une mise à jour. En
revanche, une modification du code de l’application nécessite toujours de
construire un nouvel AAB et de le publier dans Google Play Console. L’écran
Admin informe et redirige les utilisateurs ; il ne remplace pas l’envoi de
l’AAB au Play Store.

## 7. Diagnostic IA

La carte **État du service IA** devient rouge après un échec OpenAI et indique
si le problème vient du crédit, de la clé, du modèle, du débit ou du réseau.
Un appel échoué est remboursé dans le quota applicatif. Le crédit API OpenAI
reste toutefois payant et séparé de ChatGPT : le rôle Admin donne l'accès aux
fonctionnalités Premium, mais ne peut pas rendre les appels OpenAI gratuits.

## 8. Contenus pédagogiques Firestore

Le déploiement des Functions et de l'AAB ne modifie pas automatiquement les
collections de cours. La migration pédagogique préparée doit être appliquée
une seule fois avec `npm run migrate:v2:apply`. Elle est idempotente et ne
touche ni aux utilisateurs, ni aux achats, ni à leur progression.

## Sécurité

- Ne donnez jamais `admin = true` à un utilisateur ordinaire.
- Ne mettez jamais de clé OpenAI ou mot de passe dans Firestore.
- Toutes les actions sensibles sont revérifiées côté Firebase Functions.
- Les utilisateurs ne peuvent pas modifier eux-mêmes `admin`, `isAdmin`,
  `testAccess` ou `entitlements`.
- Chaque modification Admin sensible est enregistrée dans
  `_private_admin_audit`.
