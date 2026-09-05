# Firestore — Schéma (structure actuelle + gamification)

## Collections principales

### users/{uid}
- isAdmin: bool (Super Admin, champ recommandé)
- admin: bool (alias compatible avec les autres applications)
- testAccess.premium: bool (accès de test attribué par un Admin)
- activeTrack: "cip" | "sales" | "ntc"
- levelsResults: Map
  - key: "{chapterId}::{moduleId}::{level}" => { bestPercent, bestScore }
- simuDone: Map
  - key: "{chapterId}::{moduleId}" => true
- lastPlayAt / lastUpdated / lastScore / lastPercent ...

**Ajout proposé (gamification)**
- engagement: Map
  - lastActiveDay: "YYYY-MM-DD" (UTC)
  - currentStreak: int
  - bestStreak: int
  - xp: int
  - badges: Map
    - badgeId: Timestamp (earnedAt)

### chapters/{chapterId}
- track: "cip" | "sales" | "ntc"
- order: int
- title / description
- numberOfModules: int

#### chapters/{chapterId}/modules/{moduleId}
- order: int
- title / description
- resultVideos (optionnel)

### toolbox_categories/{catId}
- track: "cip" | "sales" | "ntc"
- order: int
- title

#### toolbox_categories/{catId}/items/{itemId}
- title / summary / content / tags / etc.

### tracks/{trackId}
- title / shortTitle / subtitle / badge / colors / order
- rncpReference / level / sourceUrl
- assistant.title / assistant.subtitle / assistant.suggestions
- exam.enabled / exam.kind / exam.chapterId / exam.moduleId / exam.premium

### leaderboard/{uid} (optionnel)
- uid
- displayName
- photoUrl
- xp
- updatedAt

### system/appConfig
- communication.enabled: bool
- communication.kind: announcement | update | maintenance
- communication.displayMode: banner | modal | fullscreen
- communication.audience: all | free | premium
- communication.title / message
- communication.imageUrl
- communication.actionLabel / actionUrl
- communication.dismissible / forceUpdate
- communication.minimumBuild / latestBuild
- communication.startsAt / expiresAt

Le document est lisible par l'application, mais toutes les écritures passent
par des Firebase Functions qui vérifient le rôle Admin.

## Règles d’accès (idée)
- users/{uid} : lecture/écriture uniquement par l’utilisateur (uid)
- leaderboard : lecture publique, écriture uniquement par l’utilisateur sur son doc
