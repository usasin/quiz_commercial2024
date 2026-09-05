# Déploiement EmploiBoost 2.4.1+68

## 1. Installer Android NDK r28 sous Windows

Dans Android Studio :

1. ouvrir **Tools > SDK Manager** ;
2. choisir **SDK Tools** ;
3. cocher **NDK (Side by side)** et **Show Package Details** ;
4. installer **28.0.13004108**.

## 2. Construire le bundle

Depuis PowerShell, à la racine du projet :

```powershell
flutter clean
flutter pub get
flutter analyze
flutter build appbundle --release
```

Le bundle est créé ici :

```text
build\app\outputs\bundle\release\app-release.aab
```

La version affichée par Flutter doit être `2.4.1+68`.

## 3. Publier dans Google Play Console

1. laisser la release 67 terminer son examen ;
2. créer ensuite une nouvelle release de production ;
3. importer le nouveau fichier `app-release.aab` ;
4. vérifier que Google Play affiche le code de version **68** ;
5. contrôler dans l’explorateur de bundle que l’avertissement 16 Ko a disparu.

## 4. Déploiement Firebase

Les fonctions et les règles peuvent être déployées séparément depuis Cloud Shell. La correction 16 Ko et la nouvelle interface sont incluses dans le bundle Android et ne peuvent pas être activées par un déploiement Firebase seul.
