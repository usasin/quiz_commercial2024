# EmploiBoost 2.4.1 — compatibilité Android 16 Ko

Version Flutter : `2.4.1+68`

## Correctifs Android

- compilation des bibliothèques natives avec Android NDK r28 ;
- AndroidX DataStore 1.2.1 pour corriger `libdatastore_shared_counter.so` ;
- mise à jour de `shared_preferences` vers la version 2.5.5 ;
- compatibilité avec les appareils Android utilisant des pages mémoire de 16 Ko.

## Interface Parcours

- suppression des répétitions du titre et de la description du diplôme ;
- sélecteur horizontal compact, prévu pour plusieurs parcours ;
- résumé unique du parcours actif avec sa progression ;
- chapitres visibles plus rapidement sur les petits écrans ;
- barre supérieure allégée.

## Construction obligatoire

Construire un nouveau bundle avec le numéro de build 68 :

```powershell
flutter clean
flutter pub get
flutter analyze
flutter build appbundle --release
```

Bundle attendu :

```text
build\app\outputs\bundle\release\app-release.aab
```
