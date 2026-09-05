# EmploiBoost 2.3.1 — correctif NTC interactif

Version Flutter : `2.3.1+66`

## Correctifs

- Le parcours actif est mémorisé immédiatement sur l'appareil puis synchronisé avec Firestore.
- L'examen vérifie l'identifiant, le titre, le type d'examen et la référence RNCP : un parcours RNCP39063 ne peut plus ouvrir l'examen CIP.
- Le sélecteur « Négociateur technico-commercial » s'adapte aux petits écrans et ne provoque plus de RenderFlex overflow.
- La boîte à outils et l'assistant utilisent la même source de vérité pour le parcours actif.

## Nouvelles leçons interactives

Les 36 leçons NTC proposent maintenant :

- objectifs pédagogiques ;
- points essentiels ;
- exemple terrain avec pratique à éviter, réponse experte et explication ;
- mini-défi avec correction masquée ;
- question possible du jury et réponse structurée ;
- checklist avant le quiz ;
- mémo opérationnel ;
- lecture vocale française gratuite avec la voix du téléphone.

La lecture locale ne sollicite ni OpenAI ni la Cloud Function `aiSpeech` et ne consomme donc aucun jeton IA.

## Mise à jour Firestore

Depuis le dossier `functions` :

```bash
npm ci
npm run lint
npm run migrate:ntc
npm run migrate:ntc:apply
```

La migration est déterministe et met à niveau les documents NTC existants par fusion.

## Validation locale avant Google Play

```powershell
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```
