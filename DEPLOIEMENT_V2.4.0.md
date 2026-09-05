# Déploiement EmploiBoost 2.4.0

## 1. Créer le Pass dans Google Play Console

Dans l’application EmploiBoost :

1. Ouvrir **Monétiser avec Play > Produits > Produits ponctuels**.
2. Créer le produit avec l’identifiant exact `intensive_exam_pass`.
3. Nom conseillé : **Pass entraînement intensif**.
4. Description conseillée : **Débloque un examen blanc complet supplémentaire
   avec corrections et bilan personnalisé.**
5. Ajouter une option d’achat **Acheter**.
6. Définir le prix de base à `0,99 €` et vérifier les prix locaux proposés.
7. Marquer l’option d’achat comme compatible avec les anciennes intégrations si
   la Console affiche ce choix.
8. Activer l’option d’achat, puis activer le produit.

L’identifiant est définitif après création. Il doit donc respecter exactement
les minuscules et les tirets bas indiqués ci-dessus.

## 2. Déployer la sécurité et les Functions

Depuis la racine du projet dans Cloud Shell :

```bash
cd ~/emploiboost-v240
cd functions
npm ci
npm run lint
cd ..
firebase deploy --only "functions:aiTrainingAccess,functions:aiStartTrainingSession,functions:aiRoleplay,functions:aiCoachFeedback,functions:aiCorrectWriting,functions:aiTranscribe,functions:aiSpeech,functions:verifyAndroidPurchase,functions:adminDashboardStats,functions:adminListUsers,firestore:rules" --project emploiboost
```

Cette version ne demande aucune nouvelle migration de leçons ou quiz.

## 3. Construire l’application

Sur le poste Windows :

```powershell
cd C:\dev\emploiboost
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Le bundle attendu est :

```text
build\app\outputs\bundle\release\app-release.aab
```

Version attendue : `2.4.0+67`.

## 4. Recette sur le canal Test interne

Utiliser un compte ajouté aux testeurs de licence Google Play.

1. Compte gratuit : lancer l’essai découverte et vérifier l’arrêt après 5
   réponses.
2. Compte Premium : effectuer 2 séances guidées, puis vérifier le conseil de
   révision à la troisième tentative.
3. Compte Premium : lancer l’examen inclus.
4. Revenir immédiatement dans Examen blanc : vérifier l’ouverture de la page
   Pass intensif.
5. Effectuer l’achat test du Pass, puis vérifier que l’examen démarre.
6. Vérifier dans `users/{uid}.entitlements.intensiveExamPasses` que le compteur
   revient à `0` après le démarrage.
7. Vérifier dans l’Admin les compteurs **Examens ce mois** et **Pass intensifs
   vendus**.
8. Tester les deux parcours CIP et NTC.

## 5. Protection OpenAI complémentaire

Conserver également une limite de dépense dure sur le projet OpenAI. Les
plafonds applicatifs réduisent fortement l’usage, tandis que cette limite de
facturation reste le dernier filet de sécurité en cas d’incident.

## Références officielles

- Google Play Console — produits ponctuels :
  https://support.google.com/googleplay/android-developer/answer/16430488?hl=fr
- Android Developers — cycle de vie d’un achat ponctuel :
  https://developer.android.com/google/play/billing/lifecycle/one-time
