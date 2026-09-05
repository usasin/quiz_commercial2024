# EmploiBoost / Prépa Boost — déploiement V2

Cette V2 conserve l’identifiant Android `com.emploiboost.emploiboost`, le projet Firebase `emploiboost`, les comptes Firestore et les produits Play `premium_monthly` et `premium_yearly`. Elle doit donc être publiée comme **mise à jour** de l’application existante, jamais comme une nouvelle application.

Tarifs attendus : **7,99 € par mois** et **29,99 € par an**. Ces montants doivent aussi être configurés dans les offres correspondantes de Play Console : le prix reçu depuis Google Play reste prioritaire sur le texte de secours affiché par l’application.

## Ce qui change

- version Android/Flutter : `2.2.1+64` ;
- appels OpenAI déplacés dans des Firebase Functions authentifiées ;
- clé OpenAI absente du code et de l’application Android ;
- vérification Google Play côté serveur avant activation de Premium ;
- assistant gratuit fondé sur les leçons et la boîte à outils, sans appel OpenAI ;
- quiz avec révision des erreurs, explications, compétence RNCP et lien de source ;
- examen blanc Premium en phases : sujet, préparation 15 min, entretien 30 min, écrits 20 min, questions du jury ;
- révision structurelle des 656 quiz existants, enrichissement des explications courtes et correction des formulations ambiguës ;
- ajout de 9 leçons et 72 questions pour M3_E6, M3_E7 et M3_E8 ;
- remplacement de 24 simulations M3 incohérentes par des situations employeur et de 8 simulations M2 par des situations d’atelier ;
- grilles d’évaluation adaptées aux entretiens, ateliers, employeurs et jurys ;
- règles Firestore et Storage sécurisées.
- espace Super Admin Firestore avec accès Premium de test, statistiques,
  gestion des utilisateurs et communications à distance ;
- annonces, images, liens, bannières, écrans flash et mises à jour
  facultatives ou obligatoires pilotés depuis `system/appConfig`.
- espace Mon parcours avec XP, 7 niveaux, séries, 17 badges, mission
  quotidienne et défi spécial pilotable depuis l'Admin ;
- suivi Admin des abonnés Google Play vérifiés et de leur état ;
- diagnostic Admin du service IA avec remboursement du quota applicatif après
  un appel échoué.

## 1. Prérequis locaux

Ne jamais copier la clé OpenAI dans ce dossier. Depuis la racine du projet :

```bash
firebase login
firebase use emploiboost
cd functions
npm ci
npm run lint
cd ..
```

Le projet utilise Node.js 22 pour les Functions.

## 2. Enregistrer la clé OpenAI comme secret Firebase

La commande suivante demande la valeur de façon interactive. Coller la valeur de `OPENAI_API_KEY` depuis le fichier `.env` local uniquement dans cette invite :

```bash
firebase functions:secrets:set OPENAI_API_KEY --project emploiboost
```

La valeur est enregistrée dans Google Cloud Secret Manager et n’entre ni dans Git ni dans l’AAB. Documentation : https://firebase.google.com/docs/functions/config-env

## 3. Autoriser la vérification Google Play

1. Activer **Google Play Android Developer API** dans le projet Cloud `emploiboost`.
2. Dans Google Cloud Console, relever le compte de service utilisé par les Functions de 2e génération.
3. Dans Play Console, ouvrir **Utilisateurs et autorisations**, inviter l’adresse de ce compte de service et limiter l’accès à cette application.
4. Accorder les autorisations nécessaires à la facturation : consultation des données financières/commandes et gestion des commandes/abonnements.

Google décrit ces autorisations ici : https://developers.google.com/android-publisher/getting_started

Ne télécharger ni ne partager de clé JSON de compte de service : les Functions utilisent automatiquement leur identité d’exécution.

## 4. Déployer d’abord les Functions

```bash
firebase deploy --only functions --project emploiboost
```

Vérifier ensuite dans Firebase Console que les fonctions IA, achat et Admin
sont présentes dans la région `europe-west1`.

### Notifications Google Play en temps réel

La Function `googlePlayRtdn` actualise automatiquement les résiliations,
renouvellements et incidents de paiement. Si le déploiement ne crée pas le
topic, l'ajouter une seule fois :

```powershell
gcloud pubsub topics create play-billing-rtdn --project emploiboost
gcloud pubsub topics add-iam-policy-binding play-billing-rtdn --project emploiboost --member="serviceAccount:google-play-developer-notifications@system.gserviceaccount.com" --role="roles/pubsub.publisher"
```

Dans Play Console > **Configuration de la monétisation** > **Notifications en
temps réel pour les développeurs**, saisir :

```text
projects/emploiboost/topics/play-billing-rtdn
```

Envoyer le message de test puis enregistrer. À ce volume, Pub/Sub reste
normalement dans le quota gratuit, mais la facturation Cloud doit rester
surveillée.

## 4 bis. Activer votre compte Super Admin

Cette opération se fait une seule fois dans Firebase Console :

1. Ouvrir **Firestore Database** puis la collection `users`.
2. Ouvrir le document correspondant à votre propre UID.
3. Ajouter le champ booléen `isAdmin` avec la valeur `true`.

Le champ `admin: true` est également accepté pour rester compatible avec vos
autres applications. Il ne faut en utiliser qu'un seul. Après modification,
se déconnecter puis se reconnecter dans l'application. Le bouton **Super
Admin** apparaîtra dans le Profil.

Ne jamais ajouter ce champ aux documents d'utilisateurs ordinaires. Les règles
empêchent un utilisateur de créer ou modifier lui-même `isAdmin`, `admin`,
`testAccess` ou `entitlements`.

Le tableau de bord comprend :

- total des inscrits et nouveaux comptes sur 7/30 jours ;
- droits Premium enregistrés, forfaits mensuels et annuels ;
- estimation mensuelle brute et nombre d'appels IA ;
- recherche d'utilisateurs et Premium de test séparé des achats Google ;
- annonce, image, lien, audience et durée ;
- bannière, fenêtre ou écran flash ;
- mise à jour conseillée ou obligatoire selon le numéro de build ;
- aperçu Admin en mode Premium ou utilisateur gratuit.
- abonnés vérifiés avec dates et état de renouvellement ;
- mission quotidienne et défis temporaires publiés depuis le téléphone ;
- état du service IA et cause du dernier échec.

## 5. Préparer la migration pédagogique

Une exportation Firestore existe déjà. Le script est sans écriture par défaut :

> Important : déployer les Functions ne met pas à jour les leçons, quiz et
> simulations. Les collections réelles ne changent qu'après l'exécution de
> `migrate:v2:apply` et l'affichage de « Migration appliquée ».

Sous Windows PowerShell :

```powershell
cd functions
$env:GOOGLE_CLOUD_PROJECT = "emploiboost"
gcloud auth application-default login
npm run migrate:v2
```

Lire le nombre d’écritures prévues. Puis seulement après vérification :

```powershell
npm run migrate:v2:apply
Remove-Item Env:GOOGLE_CLOUD_PROJECT
cd ..
```

Pour exécuter le script en local, initialiser au préalable les identifiants d’application Google avec `gcloud auth application-default login` ; dans Cloud Shell, l’identité du projet peut déjà être disponible.

Le script ajoute les métadonnées RNCP, corrige le champ `rubric `, pose une grille adaptée à chaque type de simulation, enrichit les leçons et explications trop courtes, applique les corrections ciblées, complète M3_E6 à M3_E8 et remplace les simulations incohérentes. Il ne supprime ni comptes, ni progression, ni droits Premium. Il est idempotent : une nouvelle exécution met à jour les mêmes documents sans créer de doublons.

## 6. Tester avant la production

Remettre localement les fichiers de signature historiques, qui ne sont volontairement pas inclus dans le paquet sécurisé :

- `android/key.properties` ;
- le fichier `.jks` référencé par `storeFile` ;
- `android/local.properties` si nécessaire.

Puis :

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Importer l’AAB dans le canal **Test interne** de la même fiche Play Store. Tester au minimum :

- connexion avec un compte gratuit ;
- assistant gratuit et liens de sources ;
- blocage de l’examen blanc pour un compte gratuit et ouverture pour Premium ;
- quiz, erreurs, chronomètre et reprise ;
- une simulation vocale et son feedback ;
- examen blanc complet ;
- restauration avec un compte déjà Premium ;
- achat mensuel ou annuel avec un testeur de licence ;
- conservation de la progression après mise à jour depuis la version publiée.

## 7. Publication progressive sans perdre les abonnés existants

1. Publier la V2 en déploiement progressif (par exemple 10 %).
2. Contrôler pendant 24 à 48 h les crashs, les erreurs Functions et les achats.
3. Passer à 50 %, puis 100 % si les contrôles restent bons.
4. Ne jamais changer le package, les identifiants produits ou le projet Firebase.

## 8. Déployer les règles sécurisées au bon moment

La V1 historique écrivait elle-même certains droits. Pour ne pas perturber un achat depuis une ancienne version, déployer les règles strictes **après** la mise à disposition de la V2 et après validation du parcours d’achat V2 :

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage --project emploiboost
```

Les règles laissent les utilisateurs modifier leur progression, mais seuls les serveurs Firebase peuvent modifier `entitlements`.

## 9. Coûts

- L’assistant « Une question ? » est gratuit côté IA : il cherche uniquement dans Firestore.
- Les simulations vocales, transcriptions et feedbacks utilisent OpenAI et peuvent coûter selon l’usage.
- Des quotas quotidiens serveur limitent les abus.
- Cloud Functions, Firestore et Secret Manager peuvent aussi entraîner des frais au-delà de leurs quotas gratuits.

### Diagnostic si la simulation IA ne répond pas

Le crédit de l’API OpenAI est indépendant d’un abonnement ChatGPT. Vérifier le
solde dans https://platform.openai.com/settings/organization/billing puis les
limites dans https://platform.openai.com/settings/organization/limits.

Pour lire la cause exacte sans afficher la clé :

```powershell
firebase functions:log --only aiTranscribe --project emploiboost
firebase functions:log --only aiRoleplay --project emploiboost
firebase functions:log --only aiSpeech --project emploiboost
```

`insufficient_quota` confirme que le crédit API est épuisé. Une erreur `401`
indique plutôt une clé invalide ou rattachée au mauvais projet. Une erreur `429`
sans `insufficient_quota` correspond à une limite de débit temporaire.

La V2 affiche maintenant ces pannes à l’écran. Un appel IA échoué est retiré du
quota quotidien et le crédit gratuit de simulation n’est consommé qu’après la
première réponse réussie.

### Sécurité immédiate de la clé OpenAI

Si une capture d'écran a montré même une partie de la clé, la considérer comme
compromise :

1. créer une nouvelle clé dans le projet OpenAI ;
2. remplacer le secret sans écrire la clé dans la commande :

```powershell
firebase functions:secrets:set OPENAI_API_KEY --project emploiboost
firebase deploy --only "functions:aiRoleplay,functions:aiCoachFeedback,functions:aiCorrectWriting,functions:aiTranscribe,functions:aiSpeech" --project emploiboost
```

3. vérifier une simulation ;
4. supprimer l'ancienne clé dans OpenAI.

Le rôle Admin ouvre gratuitement les portes Premium de l'application, mais les
transcriptions, voix et réponses OpenAI consomment toujours le solde API du
propriétaire. L'interface ne peut pas supprimer ce coût fournisseur.

## Contrôle après publication

Conserver l’export Firestore et surveiller pendant la première semaine : erreurs Functions, taux d’échec de vérification Play, abonnements actifs, coût OpenAI, questions sans résultat dans l’assistant et simulations interrompues. Aucun secret ne doit apparaître dans les logs.
