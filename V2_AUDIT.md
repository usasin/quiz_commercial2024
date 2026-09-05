# Audit V1 → V2 — EmploiBoost / Prépa Boost

## État des données vérifiées

L’export Firestore du 4 août 2026 contient :

- 5 chapitres ;
- 27 modules ;
- 74 leçons ;
- 656 questions ;
- 92 simulations ;
- 103 fiches de boîte à outils.

La base est suffisamment riche pour une V2, mais elle ne contenait pas de métadonnées de source ou de compétence. Les modules M3_E6, M3_E7 et M3_E8 disposaient de simulations mais pas de leçons ni de quiz. Seulement 9 simulations comportaient une grille d’évaluation explicite et trois documents utilisaient le champ erroné `rubric `.

Le contrôle structurel des 656 questions existantes a confirmé que chacune possède un énoncé, quatre réponses, un index de bonne réponse valide et une explication. Aucun doublon exact d’énoncé ni doublon de réponse dans une même question n’a été trouvé. En revanche, 382 explications étaient trop courtes pour vraiment aider l’utilisateur, 15 leçons faisaient moins de 250 caractères et plusieurs formulations étaient trop absolues ou ambiguës.

L’audit sémantique a également trouvé un décalage majeur en M3 : les titres et simulations de plusieurs modules restaient orientés « candidat » alors que les leçons et quiz portaient sur la relation employeur et le bloc BC03. En M2, les simulations des modules d’atelier ne correspondaient pas toujours aux leçons et aux quiz.

## Risques critiques trouvés dans la V1

- clé OpenAI embarquée dans le code et appels directs depuis le téléphone ;
- règles Firestore autorisant trop largement lecture et écriture ;
- activation Premium et crédits pilotables depuis le client ;
- fichiers de signature Android présents dans l’archive source ;
- aucune vérification serveur du reçu Google Play ;
- contenus historiques non reliés à une source vérifiable ;
- simulation d’examen trop courte par rapport aux phases officielles ;
- fin de quiz brutale après la troisième erreur et absence de reprise ciblée.

## Corrections intégrées dans la V2

- Firebase Functions de 2e génération pour jeu de rôle, transcription, voix, feedback et correction ;
- secret `OPENAI_API_KEY` géré par Secret Manager ;
- quotas serveur et messages d’erreur compréhensibles ;
- validation Google Play avant livraison de Premium ;
- maintien du package, des produits, des comptes et des droits existants ;
- règles Firestore/Storage à privilège minimal ;
- assistant pédagogique gratuit, déterministe et fondé sur le contenu Firestore ;
- examen blanc Premium en 15 + 30 + 20 minutes, suivi d’un entraînement jury ;
- grille adaptée à chaque type de simulation : entretien, atelier, employeur ou jury ;
- quiz avec explication avant la fin, révision des erreurs et source consultable ;
- contrôle structurel des 656 questions historiques, enrichissement automatique de 382 explications courtes et réécriture ciblée de 6 questions ambiguës ;
- ajout de 9 leçons et 72 questions à M3_E6, M3_E7 et M3_E8 ;
- remplacement des 24 simulations M3 par des situations réellement centrées sur l’employeur, le recrutement, l’intégration et l’offre de services ;
- remplacement de 8 simulations M2 pour les aligner avec la conception et l’animation d’ateliers ;
- enrichissement des 15 leçons trop courtes et ajout des compétences et sources RNCP ;
- statuts explicites `v2_structural_reviewed`, `v2_explanation_expanded` ou `v2_corrected`, sans prétendre à une validation pédagogique officielle.

## Référence officielle

Le cadrage V2 utilise la fiche France Compétences du titre professionnel CIP RNCP37274 :

https://www.francecompetences.fr/recherche/rncp/37274/

La fiche indique une échéance d’enregistrement au 23 mars 2028. Le rattachement au référentiel et la cohérence interne ont été contrôlés dans cette V2. Une relecture par un formateur CIP ou un professionnel connaissant les attendus de jury reste recommandée avant de présenter l’ensemble comme pédagogiquement certifié ou validé officiellement.

## Limite du contrôle dans cet environnement

La migration a été rejouée hors ligne sur une copie de l’export réel. Elle prévoit 980 écritures ciblées. Le résultat simulé contient 728 questions, 83 leçons et 92 simulations : aucune question invalide, aucune leçon de moins de 250 caractères, aucune grille absente ou mal nommée et aucune simulation M3 avec un acteur autre que l’employeur. Les comptes et documents utilisateurs ne font pas partie des collections écrites par le script.

Les Functions Node ont été contrôlées syntaxiquement et leurs dépendances ont été installées. Le SDK Flutter n’étant pas disponible dans l’environnement d’audit, `flutter analyze`, les tests Flutter et la construction de l’AAB doivent être exécutés sur la machine de publication avant le test interne Play Console.
