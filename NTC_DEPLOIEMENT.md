# Déploiement EmploiBoost 2.3.1 — parcours NTC interactif

## 1. Vérifier puis charger le contenu

Dans Cloud Shell, depuis le dossier `functions` :

```bash
npm ci
npm run lint
npm run migrate:ntc
```

Le contrôle doit afficher :

```text
Simulation NTC uniquement: 335 écritures prévues.
```

Appliquer ensuite. Le script peut être relancé : il met à jour les mêmes documents sans créer de doublons.

```bash
npm run migrate:ntc:apply
```

Résultat attendu :

```text
Migration NTC appliquée: 335 écritures prévues.
```

En version 2.3.1, cette migration ajoute aussi les exemples terrain, défis, réponses jury et métadonnées de lecture vocale aux 36 leçons.

La commande est réexécutable : les identifiants sont déterministes et les
documents sont mis à jour sans créer de doublons.

## 2. Déployer les fonctions IA généralisées

Depuis la racine du projet :

```bash
firebase deploy --only "functions:aiRoleplay,functions:aiCoachFeedback,functions:aiCorrectWriting" --project emploiboost
```

Ces fonctions sélectionnent côté serveur le diplôme et le RNCP autorisés. Le
client ne peut pas imposer librement un intitulé dans le prompt système.

## 3. Vérifier l’application sur le poste Windows

```powershell
cd C:\dev\emploiboost
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Le fichier attendu est :

```text
build\app\outputs\bundle\release\app-release.aab
```

Version : `2.3.0+65`.

## 4. Scénario de recette interne

1. Ouvrir **Mon parcours** et sélectionner **NTC • Commercial terrain**.
2. Vérifier les 3 chapitres et les 12 modules.
3. Ouvrir une leçon, puis les trois niveaux de quiz.
4. Lancer une simulation et vérifier que le coach parle bien de commercial,
   de prospect ou de client, jamais de bénéficiaire CIP.
5. Ouvrir le Coach Commercial et vérifier que ses résultats proviennent
   uniquement des leçons et fiches NTC.
6. Avec un compte Premium/Admin, tirer un sujet d’examen NTC.
7. Tester la correction des écrits, l’appel, la négociation, la SWOT et le
   bilan final.
8. Revenir sur CIP et vérifier que son Assistant et son examen restent isolés.

## 5. Publication

Publier le build 65 d’abord sur le canal **Tests internes** Google Play. Ne
passer en production qu’après la recette complète sur au moins un petit et un
grand écran Android.
