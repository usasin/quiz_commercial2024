# Firestore — Règles pour entitlements (Premium + crédits)

## Schéma
- `users/{uid}` contient un champ:

```json
{
  "entitlements": {
    "isPremium": true,
    "simCredits": 12,
    "activePlan": "PREMIUM_MONTHLY",
    "updatedAt": "<timestamp>"
  }
}
```

## Règles recommandées (minimal)
Autoriser chaque utilisateur à lire/écrire son propre doc `users/{uid}`.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

> Remarque: ces règles sont adaptées à ton schéma actuel (tu écris déjà dans `users/{uid}`).
> Si tu as d'autres collections publiques (leaderboard...), garde tes règles existantes et ajoute
> seulement la partie `users/{uid}` ci-dessus.
