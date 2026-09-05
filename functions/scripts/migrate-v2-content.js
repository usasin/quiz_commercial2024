"use strict";

const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

initializeApp({credential: applicationDefault(), projectId: "emploiboost"});
const db = getFirestore();
const APPLY = process.argv.includes("--apply");
const RNCP_URL = "https://www.francecompetences.fr/recherche/rncp/37274/";

const competencyByModule = {
  F0_TERR: "BC01 • Veille, territoire, équipe, réseau et partenariat",
  F0_POSTURE: "BC01 • Posture, éthique et cadre professionnel",
  M1_E1: "BC01 • Informer une personne ou un groupe et poser le cadre",
  M1_E2: "BC01 • Analyser la demande de la personne",
  M1_E3: "BC01 • Analyser la demande et repérer les priorités",
  M1_E4: "BC01 • Recueillir les informations utiles au diagnostic",
  M1_E5: "BC01 • Poser les bases d’un diagnostic partagé",
  M1_E6: "BC01 • Reformuler et valider le diagnostic partagé",
  M1_E7: "BC01 • Mobiliser les ressources et formaliser une première étape",
  M1_E8: "BC01 • Mise en situation, synthèse et analyse de pratique",
  M2_E1: "BC02 • Contractualiser et suivre le parcours",
  M2_E2: "BC02 • Accompagner l’élaboration du projet professionnel",
  M2_E3: "BC02 • Accompagner la réalisation du projet professionnel",
  M2_E4: "BC02 • Formuler des objectifs et étapes de parcours",
  M2_E5: "BC02 • Construire et suivre un plan d’action",
  M2_E6: "BC02 • Mobiliser les ressources utiles au parcours",
  M2_E7: "BC02 • Ajuster l’accompagnement et analyser les résistances",
  M2_E8: "BC02 • Suivre, évaluer et analyser sa pratique",
  M3_E1: "BC03 • Déployer des actions de prospection employeurs",
  M3_E2: "BC03 • Structurer une offre de services aux employeurs",
  M3_E3: "BC03 • Analyser le besoin de recrutement",
  M3_E4: "BC03 • Apporter un appui technique au recrutement",
  M3_E5: "BC03 • Développer et suivre la relation employeur",
  M3_E6: "BC03 • Apporter un appui technique au recrutement",
  M3_E7: "BC03 • Faciliter l’intégration et le maintien du salarié",
  M3_E8: "BC03 • Développement durable, inclusion et bilan de l’offre",
  CERT_JURY: "Certification • Analyse de pratique et entretien final",
};

const v2Modules = {
  M3_E6: {
    title: "6. Appui technique au recrutement inclusif",
    description: "Aider l’employeur à objectiver son besoin et sécuriser un recrutement inclusif.",
    lessons: [
      ["L1", "Transformer le besoin en critères observables", "Un besoin de recrutement doit être traduit en activités, compétences attendues, contraintes réelles et critères observables. Le CIP distingue les exigences indispensables de celles qui peuvent être acquises ou adaptées. Il reformule avec l’employeur et vérifie qu’aucun critère ne repose sur une habitude, un stéréotype ou une préférence sans lien avec le poste.", 1],
      ["L2", "Préparer une mise en relation ciblée", "Le CIP ne promet pas un candidat parfait. Il présente des éléments factuels : compétences, expériences, disponibilité, contraintes connues et besoins éventuels d’adaptation. Il recueille l’accord de la personne avant la transmission de ses informations et prépare chaque partie aux conditions concrètes de la rencontre.", 2],
      ["L3", "Sécuriser l’entretien et la décision", "L’appui technique peut porter sur une grille d’entretien commune, des questions liées aux activités du poste et des critères identiques pour les candidats. Le CIP prévient les discriminations, aide à distinguer compétence et impression, puis formalise la décision et la prochaine étape sans se substituer à l’employeur.", 3],
    ],
    themes: [
      ["critères observables", "décrire activités et preuves attendues", "l’employeur demande quelqu’un de dynamique", "traduire dynamique en comportements liés au poste", "Pourquoi refusez-vous le critère de personnalité ?", "un critère doit être lié aux activités et observable"],
      ["indispensable ou souhaitable", "hiérarchiser les exigences du poste", "toutes les compétences sont annoncées obligatoires", "distinguer prérequis et compétences acquérables", "Pourquoi négocier les critères ?", "élargir le recrutement sans diminuer les exigences essentielles"],
      ["consentement", "obtenir l’accord avant de transmettre des informations", "l’employeur réclame le dossier complet", "transmettre seulement les données utiles avec accord", "Pourquoi limiter les informations ?", "respecter la personne, la confidentialité et la finalité du recrutement"],
      ["non-discrimination", "écarter les critères sans lien direct avec l’emploi", "une préférence d’âge est exprimée", "recentrer sur les compétences et le cadre légal", "Comment réagissez-vous à un critère discriminatoire ?", "rappeler le cadre et proposer des critères professionnels"],
      ["grille d’entretien", "poser les mêmes questions de base liées au poste", "la décision repose sur le ressenti", "proposer une grille commune et des preuves", "À quoi sert votre grille ?", "objectiver et rendre comparables les éléments recueillis"],
      ["mise en relation", "présenter une adéquation factuelle sans sur-promesse", "l’employeur veut une garantie de réussite", "expliquer ce qui est vérifié et ce qui reste à confirmer", "Pourquoi ne garantissez-vous pas le candidat ?", "rester fiable et organiser la sécurisation après recrutement"],
      ["adaptation", "identifier les marges d’adaptation du poste", "une contrainte semble bloquante", "questionner horaires, organisation et aménagements possibles", "Pourquoi parler d’adaptation ?", "chercher une adéquation réaliste et inclusive"],
      ["traçabilité", "formaliser critères, décision et prochaine étape", "les échanges restent uniquement oraux", "rédiger un relevé factuel et daté", "Pourquoi tracer votre appui ?", "assurer continuité, équité et suivi"],
    ],
  },
  M3_E7: {
    title: "7. Suivre l’intégration et prévenir les ruptures",
    description: "Préparer l’arrivée, suivre l’intégration et agir précocement sur les difficultés.",
    lessons: [
      ["L1", "Préparer l’intégration avant le premier jour", "L’intégration se prépare avec l’employeur et la personne : horaires, accès, tenue, consignes, interlocuteur, activités des premiers jours et besoins d’adaptation. Le CIP vérifie que chacun connaît son rôle et fixe un premier point de suivi. Cette préparation réduit les malentendus et les ruptures précoces.", 1],
      ["L2", "Organiser un suivi tripartite proportionné", "Le suivi respecte l’autonomie du salarié et les responsabilités de l’employeur. Avec l’accord de la personne, le CIP organise des points courts et factuels. Il distingue les faits, les perceptions et les attentes, recherche des ajustements concrets et fixe qui fait quoi avant le prochain point.", 2],
      ["L3", "Traiter une difficulté sans désigner de coupable", "Lorsqu’une difficulté apparaît, le CIP agit rapidement : recueillir séparément les faits, identifier l’écart entre attendu et réalisé, vérifier les consignes et les conditions de travail, puis construire une solution testable. En cas de santé, handicap, sécurité ou droit du travail, il mobilise les professionnels compétents.", 3],
    ],
    themes: [
      ["préparation", "clarifier les conditions du premier jour", "le salarié ignore où se présenter", "confirmer lieu, heure et interlocuteur", "Pourquoi intervenir avant la prise de poste ?", "prévenir une rupture liée à un problème évitable"],
      ["tuteur", "identifier un interlocuteur disponible", "personne ne sait qui accompagne le nouvel arrivant", "désigner un référent et ses modalités d’appui", "Pourquoi demander un tuteur ?", "sécuriser l’apprentissage et les retours"],
      ["suivi tripartite", "définir un suivi avec l’accord des parties", "l’employeur veut tout signaler sans informer le salarié", "rappeler le cadre et organiser un échange transparent", "Comment respectez-vous la confidentialité ?", "partager uniquement les informations utiles avec accord"],
      ["faits", "distinguer faits, attentes et interprétations", "l’employeur dit qu’il n’est pas motivé", "demander des situations précises et observables", "Pourquoi refusez-vous l’étiquette ?", "comprendre l’écart réel avant d’agir"],
      ["ajustement", "tester une solution précise et datée", "une consigne n’est pas comprise", "reformuler, montrer et vérifier la compréhension", "Comment mesurez-vous l’effet ?", "fixer un indicateur et une date de bilan"],
      ["alerte précoce", "agir dès les premiers signaux", "retards répétés sans échange", "recueillir les causes et convenir d’une action", "Pourquoi ne pas attendre ?", "éviter l’installation du conflit ou de la rupture"],
      ["relais compétent", "mobiliser le bon professionnel selon le besoin", "une restriction de santé est évoquée", "orienter vers les acteurs compétents sans poser de diagnostic", "Quelle est votre limite professionnelle ?", "le CIP coordonne mais ne remplace pas le médecin ou le spécialiste"],
      ["bilan", "formaliser acquis, difficultés et suite", "la période d’intégration se termine", "réaliser un bilan partagé et décider du suivi", "Pourquoi faire un bilan même si tout va bien ?", "capitaliser les réussites et prévenir les difficultés futures"],
    ],
  },
  M3_E8: {
    title: "8. Piloter une offre employeur durable et inclusive",
    description: "Évaluer l’action, améliorer le partenariat et inscrire ses pratiques dans une démarche inclusive et durable.",
    lessons: [
      ["L1", "Piloter une action employeur comme un projet", "Une action de prospection part d’un diagnostic territorial, d’objectifs, de cibles, d’un calendrier et d’indicateurs. Le CIP suit les contacts, besoins qualifiés, mises en relation et suites obtenues. Il analyse les résultats pour ajuster son action plutôt que de mesurer uniquement le nombre d’appels.", 1],
      ["L2", "Rendre l’offre de services inclusive", "Une offre inclusive questionne l’accessibilité des informations, des entretiens, des postes et de l’intégration. Le CIP recherche les adaptations raisonnables, lutte contre les stéréotypes et valorise les compétences. Il s’appuie sur les partenaires compétents et ne promet jamais une aide ou un aménagement sans vérification.", 2],
      ["L3", "Développement durable et amélioration continue", "Le CIP limite les démarches inutiles, privilégie des mises en relation pertinentes, utilise les outils numériques de façon responsable et tient compte des possibilités de mobilité. Il recueille le retour des personnes et des employeurs, identifie les écarts et formalise une amélioration concrète pour l’action suivante.", 3],
    ],
    themes: [
      ["diagnostic territorial", "partir de besoins et données du territoire", "la prospection est faite au hasard", "définir secteurs, cibles et objectifs", "Pourquoi cibler votre action ?", "relier les moyens aux besoins observés"],
      ["indicateurs", "mesurer contacts utiles, besoins et suites", "seul le nombre d’appels est suivi", "ajouter qualité des besoins et résultats", "Quel indicateur démontre la valeur ?", "mesurer une progression vers l’insertion durable"],
      ["accessibilité", "vérifier l’accès à l’information et au recrutement", "un processus uniquement numérique exclut des candidats", "proposer une modalité accessible", "Pourquoi questionner le canal ?", "garantir une possibilité réelle de participation"],
      ["inclusion", "valoriser les compétences et adaptations possibles", "un stéréotype influence la sélection", "recentrer sur preuves et besoins du poste", "Quelle posture adoptez-vous ?", "conseiller sans culpabiliser et rappeler le cadre"],
      ["partenariat", "définir des engagements réalistes et réciproques", "l’employeur attend des profils sans donner de retour", "convenir des modalités de retour et de suivi", "Pourquoi formaliser la collaboration ?", "améliorer la confiance et la qualité du service"],
      ["durabilité", "éviter les démarches sans valeur et les déplacements inutiles", "plusieurs rendez-vous redondants sont prévus", "regrouper les échanges et choisir le canal adapté", "Comment reliez-vous cela au métier ?", "concilier efficacité, accessibilité et impact"],
      ["retour d’expérience", "recueillir les points de vue des deux parties", "une action est terminée sans bilan", "organiser un retour factuel et partagé", "Pourquoi analyser un succès ?", "identifier ce qui doit être reproduit ou amélioré"],
      ["amélioration continue", "choisir une amélioration observable", "le bilan conclut seulement qu’il faut faire mieux", "définir action, responsable, date et indicateur", "Que présentez-vous au jury ?", "une décision argumentée issue de l’analyse"],
    ],
  },
};

const moduleCorrections = {
  M2_E4: ["4. Concevoir et préparer un atelier thématique", "Définir un objectif, un cadre, une progression et des modalités accessibles."],
  M2_E5: ["5. Suivre le parcours et ajuster le plan d’action", "Analyser les réalisations, les blocages et convenir d’une suite réaliste avec la personne."],
  M2_E6: ["6. Mobiliser les ressources utiles au parcours", "Identifier les relais adaptés et organiser une orientation concrète, consentie et traçable."],
  M2_E7: ["7. Animer un atelier et gérer les dynamiques de groupe", "Favoriser la participation, recadrer avec bienveillance et conclure par une mise en action."],
  M2_E8: ["8. Prévenir les ruptures et analyser sa pratique", "Repérer les signes de décrochage, ajuster le suivi et tirer des enseignements de son intervention."],
  M3_E1: ["1. Prospecter les employeurs du territoire", "Préparer une action de prospection ciblée et obtenir une prochaine étape utile."],
  M3_E2: ["2. Qualifier le besoin de recrutement", "Transformer une demande parfois vague en activités, contraintes et critères observables."],
  M3_E3: ["3. Mettre en relation sans survendre", "Présenter une adéquation factuelle avec l’accord de la personne et sécuriser la rencontre."],
  M3_E4: ["4. Sécuriser la prise de poste", "Préparer l’arrivée, les consignes, le tutorat et les premiers points de suivi."],
  M3_E5: ["5. Fidéliser le partenariat employeur", "Réaliser un bilan utile, obtenir des retours et convenir d’engagements réciproques."],
  M3_E6: ["6. Appui technique au recrutement inclusif", "Objectiver la sélection, prévenir les discriminations et proposer des adaptations réalistes."],
  M3_E7: ["7. Suivre l’intégration et prévenir les ruptures", "Traiter rapidement les difficultés à partir des faits et construire des ajustements suivis."],
  M3_E8: ["8. Piloter une offre employeur durable et inclusive", "Évaluer les résultats, l’accessibilité et améliorer l’action menée avec les employeurs."],
};

const questionOverrides = {
  "chapters/F0/modules/F0_POSTURE/levels/level_easy/questions/qHX7gSz2X5XN6NKvjddw": {
    question: "Lors d’un premier entretien, quel cadrage favorise une relation claire ?",
    options: [
      "Rôle, sanctions et engagement de résultat",
      "Rôle, objectif de l’échange, durée indicative, confidentialité et accord pour les notes",
      "Documents exigés et plan complet décidé à l’avance",
      "Présentation de tous les dispositifs disponibles",
    ], correctAnswer: 1,
    explanation: "Le cadrage doit être compréhensible et adapté au contexte. Il précise notamment le rôle du CIP, l’objectif de l’échange, une durée indicative, le traitement des informations et l’accord de la personne pour la prise de notes.",
  },
  "chapters/M1/modules/M1_E1/levels/level_easy/questions/4aqB07pd8guaxufOMNKE": {
    question: "Au début de l’entretien, quels éléments faut-il généralement clarifier ?",
    options: [
      "Rôle, objectif de l’échange, durée indicative, confidentialité et accord",
      "Sanctions, obligations et solution déjà choisie",
      "Tous les dispositifs, leurs délais et leurs formulaires",
      "Diagnostic définitif et plan d’action complet",
    ], correctAnswer: 0,
    explanation: "Un cadre clair sécurise l’échange sans le rigidifier. Il est adapté à la structure, au public et à la situation, puis vérifié avec la personne.",
  },
  "chapters/M1/modules/M1_E3/levels/level_easy/questions/cmpcKPzxuKmymfHzaDNU": {
    question: "La personne cherche un emploi et signale un hébergement instable. Quelle conduite est la plus professionnelle ?",
    options: [
      "Ignorer le logement pour rester uniquement sur l’emploi",
      "Évaluer l’urgence, proposer un relais adapté et maintenir les démarches d’emploi compatibles",
      "Suspendre automatiquement tout accompagnement professionnel",
      "Décider seul d’une orientation vers l’hébergement",
    ], correctAnswer: 1,
    explanation: "Le CIP évalue avec la personne le niveau d’urgence et mobilise un relais adapté. Les actions d’insertion compatibles peuvent continuer en parallèle afin de ne pas interrompre inutilement la dynamique.",
  },
  "chapters/M1/modules/M1_E3/levels/level_expert/questions/ekdFWnneJckbB3vJXSoA": {
    question: "Une ressource territoriale est pertinente lorsqu’elle est :",
    options: [
      "Très connue, même si elle ne répond pas au besoin",
      "Adaptée au besoin et accessible dans un délai utile",
      "Éloignée afin de tester la motivation",
      "Choisie sans vérifier ses conditions d’accès",
    ], correctAnswer: 1,
    explanation: "La pertinence dépend du besoin, des critères d’accès, du délai, de l’accessibilité et de l’accord de la personne. Le CIP vérifie ces éléments avant d’orienter.",
  },
  "chapters/M1/modules/M1_E3/levels/level_medium/questions/V7VDI7soZ5evi6qJbEcc": {
    question: "Lorsqu’une urgence est repérée, quelle logique d’intervention est la plus juste ?",
    options: [
      "Sécuriser l’urgence et maintenir, si possible, les actions d’insertion compatibles",
      "Traiter uniquement l’emploi, quelle que soit la situation",
      "Interrompre automatiquement tout le parcours",
      "Attendre le rendez-vous suivant sans proposer de relais",
    ], correctAnswer: 0,
    explanation: "L’urgence est évaluée et traitée avec les acteurs compétents. Le reste du parcours n’est pas abandonné : il est adapté au rythme, aux priorités et aux possibilités réelles de la personne.",
  },
  "chapters/M2/modules/M2_E6/levels/level_expert/questions/QU1AGUuRskHaQPKiLYdi": {
    question: "Des documents administratifs nécessaires au parcours ne sont pas à jour. Quel réflexe adopter ?",
    options: [
      "Promettre une régularisation rapide",
      "Clarifier le blocage, informer sur ses limites, mobiliser un relais compétent et dater la suite",
      "Demander des informations sans lien avec la démarche",
      "Ignorer la difficulté et multiplier les candidatures",
    ], correctAnswer: 1,
    explanation: "Le CIP ne se substitue pas au professionnel compétent. Il aide à comprendre l’étape nécessaire, vérifie les modalités du relais et maintient une continuité de parcours réaliste.",
  },
};

const explanationSuffixByChapter = {
  F0: "Le choix professionnel doit rester explicable, proportionné et respectueux du cadre, de la personne et des limites du rôle du CIP.",
  M1: "La réponse attendue part des faits, vérifie la compréhension de la personne et prépare une suite réaliste sans décider à sa place.",
  M2: "La pratique attendue associe co-construction, faisabilité, date de suivi et possibilité d’ajuster le parcours avec la personne.",
  M3: "La décision doit être reliée au besoin réel de l’employeur, aux compétences, à la non-discrimination et à une insertion durable.",
  CERT: "Devant le jury, il faut relier un fait observable, l’intention professionnelle et une amélioration concrète sans inventer d’information.",
};

const lessonExtensionByChapter = {
  F0: "\n\nMise en pratique : formule le cadre avec des mots simples, demande l’accord de la personne et vérifie ce qu’elle a compris. Point de vigilance : une règle interne ne remplace pas l’explication de sa finalité ni l’adaptation à la situation.",
  M1: "\n\nMise en pratique : repère les faits, reformule sans jugement et demande à la personne de valider ta compréhension. Termine par une prochaine étape réaliste, consentie et datée. Le CIP oriente vers les professionnels compétents lorsqu’une situation dépasse son rôle.",
  M2: "\n\nMise en pratique : transforme l’objectif en une action observable, précise qui fait quoi et fixe un point de suivi. Si l’étape n’est pas réalisée, recherche le blocage avec la personne avant d’ajuster, sans sanction automatique ni jugement.",
  M3: "\n\nMise en pratique : appuie-toi sur des critères liés au poste, distingue les faits des impressions et formalise la prochaine étape. Ne promets ni candidat parfait ni résultat ; vérifie le consentement avant toute transmission d’information.",
  CERT: "\n\nEntraînement jury : réponds en trois temps — fait observé, intention professionnelle, amélioration possible. Cite une phrase ou une action précise de l’entretien et indique honnêtement ce que tu n’as pas pu vérifier.",
};

const employerRubric = {
  version: 2, passThreshold: 70,
  criteria: [
    {name: "Analyse du besoin et questions utiles", weight: 25},
    {name: "Critères observables et non-discrimination", weight: 20},
    {name: "Proposition de service réaliste", weight: 20},
    {name: "Posture, écoute et communication", weight: 20},
    {name: "Prochaine étape et traçabilité", weight: 15},
  ],
};

const interviewRubric = {
  version: 2, passThreshold: 70,
  criteria: [
    {name: "Cadre, confidentialité et posture", weight: 20},
    {name: "Écoute, questions et reformulations", weight: 25},
    {name: "Analyse factuelle et diagnostic partagé", weight: 25},
    {name: "Co-construction d’une suite réaliste", weight: 20},
    {name: "Traçabilité et limites professionnelles", weight: 10},
  ],
};

const workshopRubric = {
  version: 2, passThreshold: 70,
  criteria: [
    {name: "Objectif, cadre et progression", weight: 25},
    {name: "Accessibilité des consignes et supports", weight: 20},
    {name: "Participation et dynamique de groupe", weight: 25},
    {name: "Gestion des situations difficiles", weight: 15},
    {name: "Évaluation et mise en action finale", weight: 15},
  ],
};

const juryRubric = {
  version: 2, passThreshold: 70,
  criteria: [
    {name: "Faits et preuves issus de la situation", weight: 25},
    {name: "Justification de la démarche", weight: 25},
    {name: "Posture et limites professionnelles", weight: 20},
    {name: "Analyse réflexive", weight: 20},
    {name: "Clarté et structure de la réponse", weight: 10},
  ],
};

function rubricFor(chapterId, moduleId, actor) {
  if (actor === "jury" || chapterId === "CERT") return juryRubric;
  if (chapterId === "M3") return employerRubric;
  if (moduleId === "M2_E4" || moduleId === "M2_E7") return workshopRubric;
  return interviewRubric;
}

const m3EmployerSimulations = {
  M3_E1: [
    ["Prospection : employeur pressé", "Je n’ai que deux minutes, qu’est-ce que vous me proposez concrètement ?", "pressé", ["Présenter le rôle du CIP en une phrase", "Qualifier rapidement le contexte", "Obtenir une prochaine étape"], ["Accroche courte", "Deux questions utiles", "Valeur proposée", "Prochaine étape"], ["Réciter tous les services", "Promettre des candidats", "Insister sans accord"]],
    ["Prospection : employeur peu intéressé", "Nous recrutons seuls, je ne vois pas ce que votre service peut apporter.", "réservé", ["Explorer le fonctionnement actuel", "Identifier un irritant éventuel", "Proposer une valeur réaliste"], ["Accueillir la réserve", "Questionner", "Reformuler", "Proposer un contact utile"], ["Critiquer ses recrutements", "Forcer un rendez-vous", "Garantir un résultat"]],
    ["Prospection : demande immédiate de CV", "Envoyez-moi des CV aujourd’hui, je vous expliquerai le poste après.", "directif", ["Ne pas transmettre sans besoin qualifié", "Expliquer l’intérêt des critères", "Convenir d’un échange court"], ["Cadrer", "Qualifier activités et contraintes", "Expliquer la mise en relation", "Dater la suite"], ["Envoyer des profils au hasard", "Collecter des données inutiles", "Refuser sans alternative"]],
  ],
  M3_E2: [
    ["Besoin vague : personne sérieuse et dynamique", "Je veux surtout quelqu’un de sérieux, dynamique et qui s’intègre vite.", "impatient", ["Transformer les qualités en comportements observables", "Distinguer indispensable et souhaitable", "Vérifier les conditions du poste"], ["Activités", "Contraintes", "Critères observables", "Délai"], ["Valider des étiquettes", "Ajouter ses préférences", "Oublier les conditions réelles"]],
    ["Contraintes nombreuses et toutes obligatoires", "Pour moi, tout est indispensable : expérience, permis, disponibilité totale et autonomie immédiate.", "exigeant", ["Hiérarchiser les exigences", "Questionner leur lien avec le poste", "Identifier ce qui peut être appris ou adapté"], ["Reprendre chaque exigence", "Demander une preuve d’utilité", "Classer", "Valider le besoin"], ["Diminuer les exigences essentielles", "Accepter sans question", "Promettre un profil rare"]],
    ["Critère potentiellement discriminatoire", "Je préfère quelqu’un de jeune, ce sera plus simple pour l’équipe.", "convaincu", ["Recadrer sans agressivité", "Rappeler les critères professionnels", "Proposer une alternative observable"], ["Accueillir", "Nommer le risque", "Recentrer sur le poste", "Formaliser les critères"], ["Approuver", "Moraliser longuement", "Transmettre des profils selon l’âge"]],
  ],
  M3_E3: [
    ["Matching : recherche du candidat parfait", "Je veux être certain que la personne conviendra parfaitement avant de la rencontrer.", "prudent", ["Présenter les éléments vérifiés", "Nommer ce qui reste à confirmer", "Proposer une rencontre sécurisée"], ["Besoin", "Éléments d’adéquation", "Points à confirmer", "Suite"], ["Garantir la réussite", "Masquer un risque", "Survendre la personne"]],
    ["Transmission d’informations personnelles", "Envoyez-moi son dossier complet, y compris sa situation personnelle.", "insistant", ["Limiter les données à la finalité", "Vérifier le consentement", "Proposer une présentation professionnelle"], ["Clarifier le besoin d’information", "Rappeler le cadre", "Présenter les données utiles", "Obtenir l’accord"], ["Tout transmettre", "Inventer un accord", "Rompre l’échange sans explication"]],
    ["Risque de mobilité à présenter", "Le poste commence à 5 heures. Votre candidat pourra vraiment être là tous les jours ?", "concret", ["Rester factuel", "Présenter la solution vérifiée", "Organiser un point de confirmation"], ["Contrainte", "Faits vérifiés", "Solution ou adaptation", "Prochaine vérification"], ["Minimiser le risque", "Parler à la place du candidat", "Promettre sans preuve"]],
  ],
  M3_E4: [
    ["Prise de poste sans référent", "Il commence lundi, mais personne n’a vraiment le temps de l’accompagner.", "débordé", ["Identifier un interlocuteur", "Clarifier les premières activités", "Fixer un point de suivi"], ["Premier jour", "Référent", "Consignes", "Suivi"], ["Se substituer au manager", "Laisser démarrer sans repères", "Multiplier les documents"]],
    ["Consignes mal comprises en première semaine", "Il fait des erreurs, pourtant les consignes ont été données une fois.", "agacé", ["Recueillir des faits", "Vérifier la compréhension et le support", "Proposer un ajustement testable"], ["Faits", "Attendu", "Écart", "Ajustement", "Date de bilan"], ["Étiqueter la personne", "Prendre parti", "Proposer une sanction"]],
    ["Horaires incompatibles avant l’arrivée", "Nous venons de modifier les horaires. J’espère que cela ne posera pas de problème.", "pragmatique", ["Mesurer l’impact", "Associer la personne avec son accord", "Explorer les adaptations possibles"], ["Nouveau besoin", "Conséquences", "Options", "Décision partagée"], ["Décider pour la personne", "Cacher le changement", "Promettre une solution de transport"]],
  ],
  M3_E5: [
    ["Bilan avec un employeur satisfait", "Tout s’est bien passé. Nous pouvons en rester là, non ?", "satisfait", ["Valoriser les résultats", "Recueillir les facteurs de réussite", "Convenir d’une relation future"], ["Résultats", "Facteurs de réussite", "Améliorations", "Prochaine étape"], ["Demander immédiatement un nouveau poste", "Faire un bilan vague", "S’attribuer seul la réussite"]],
    ["Absence de retour après mise en relation", "Je n’ai pas le temps de faire un retour sur chaque candidat.", "pressé", ["Expliquer l’utilité du retour", "Proposer un format court", "Formaliser un engagement réaliste"], ["Accueillir la contrainte", "Montrer la valeur", "Proposer un canal", "Dater"], ["Culpabiliser", "Renoncer à tout suivi", "Partager le mécontentement du candidat"]],
    ["Réactiver un partenaire employeur", "Cela fait longtemps que nous n’avons pas travaillé ensemble. Pourquoi reprendre maintenant ?", "curieux", ["Rappeler le contexte sans pression", "Présenter une information utile", "Explorer les besoins actuels"], ["Historique", "Actualité utile", "Question ouverte", "Suite"], ["Inventer un besoin", "Faire une relance générique", "Promettre des profils"]],
  ],
  M3_E6: [
    ["Entretien fondé sur le ressenti", "En général je sais en cinq minutes si la personne fera l’affaire.", "sûr de lui", ["Questionner sans dévaloriser", "Proposer des critères communs", "Relier les questions aux activités"], ["Pratique actuelle", "Risque", "Grille", "Décision tracée"], ["Accuser de discriminer", "Imposer un outil", "Remplacer le recruteur"]],
    ["Épreuve technique à objectiver", "Je voudrais les tester, mais je ne sais pas vraiment quoi observer.", "demandeur", ["Partir d’une activité réelle", "Définir des indicateurs observables", "Prévoir les mêmes conditions"], ["Activité", "Consigne", "Critères", "Conditions", "Retour"], ["Créer une épreuve sans lien", "Modifier les critères selon le candidat", "Noter la personnalité"]],
    ["Besoin d’adaptation du poste", "La candidature est intéressante, mais une contrainte semble compliquer l’organisation.", "hésitant", ["Explorer les tâches et marges d’adaptation", "Respecter le consentement", "Mobiliser les relais compétents"], ["Faits", "Besoins du poste", "Adaptations possibles", "Relais", "Décision"], ["Demander un diagnostic", "Divulguer une information", "Promettre une aide non vérifiée"]],
  ],
  M3_E7: [
    ["Retards répétés pendant l’intégration", "Il est arrivé en retard trois fois. Je commence à perdre confiance.", "déçu", ["Recueillir les faits", "Faire préciser l’impact", "Construire un ajustement et son suivi"], ["Faits", "Attendu", "Causes à explorer", "Ajustement", "Date"], ["Excuser sans vérifier", "Accuser la personne", "Promettre que cela cessera"]],
    ["Tension avec un collègue", "L’équipe dit qu’il ne s’intègre pas et le ton monte.", "inquiet", ["Distinguer faits et impressions", "Préparer un échange encadré", "Définir une règle et un suivi"], ["Situations précises", "Points de vue", "Cadre", "Solution testable"], ["Désigner un coupable", "Transmettre des confidences", "Minimiser la tension"]],
    ["Difficulté liée à la santé évoquée", "La personne dit qu’elle ne peut plus réaliser certaines tâches. Que devons-nous faire ?", "préoccupé", ["Respecter les limites du CIP", "Sécuriser la situation immédiate", "Orienter vers les professionnels compétents"], ["Faits de travail", "Sécurité", "Consentement", "Relais compétent", "Suivi"], ["Poser un diagnostic", "Demander des détails médicaux", "Conseiller une décision contractuelle"]],
  ],
  M3_E8: [
    ["Indicateurs limités au nombre d’appels", "Nous avons fait beaucoup d’appels, donc l’action est forcément réussie.", "enthousiaste", ["Valoriser l’effort", "Ajouter des indicateurs de qualité et de résultat", "Proposer un bilan"], ["Objectif", "Activité", "Résultats", "Qualité", "Amélioration"], ["Nier le travail réalisé", "Ne suivre que les embauches", "Inventer des résultats"]],
    ["Processus de recrutement uniquement numérique", "Tout se fait en ligne chez nous, nous ne prévoyons pas d’autre solution.", "ferme", ["Identifier les risques d’exclusion", "Proposer une modalité accessible", "Préserver l’efficacité du processus"], ["Public concerné", "Obstacle", "Alternative", "Mise en œuvre"], ["Accuser l’employeur", "Supprimer le numérique", "Promettre une adaptation impossible"]],
    ["Bilan durable d’une action employeur", "L’action est terminée. Que devons-nous vraiment analyser pour la prochaine fois ?", "ouvert", ["Recueillir les retours", "Examiner résultats, accessibilité et moyens", "Choisir une amélioration mesurable"], ["Résultats", "Retours", "Impacts", "Écart", "Action d’amélioration"], ["Faire un bilan uniquement positif", "Rester général", "Multiplier les indicateurs inutiles"]],
  ],
};

const m2WorkshopSimulations = {
  M2_E4: [
    ["Ouvrir un atelier avec un cadre clair", "Je ne comprends pas ce qu’on va faire ni pourquoi je dois rester.", "sceptique", ["Présenter un objectif concret", "Poser un cadre compréhensible", "Vérifier l’adhésion du groupe"], ["Accueil", "Objectif", "Cadre", "Déroulé", "Question de vérification"], ["Lire un règlement", "Menacer de sanction", "Commencer sans vérifier"]],
    ["Relancer un groupe silencieux", "Personne ne répond… On doit vraiment parler devant tout le monde ?", "réservé", ["Normaliser le silence", "Proposer une participation progressive", "Préserver le droit de ne pas s’exposer"], ["Question simple", "Réflexion individuelle", "Échange en binôme", "Mise en commun volontaire"], ["Désigner une personne", "Remplir soi-même le silence", "Confondre participation et prise de parole"]],
    ["Recadrer une personne qui monopolise", "Attendez, j’ai encore beaucoup de choses à raconter au groupe.", "très bavard", ["Reconnaître la contribution", "Rappeler la règle commune", "Redonner la parole au groupe"], ["Interrompre avec respect", "Reformuler", "Rappeler le temps", "Distribuer la parole"], ["Humilier", "Laisser déborder", "Couper sans expliquer"]],
    ["Conclure par une production utile", "C’était intéressant, mais concrètement on repart avec quoi ?", "pragmatique", ["Faire reformuler l’acquis", "Obtenir une preuve ou production", "Définir une action datée"], ["Synthèse", "Production", "Action", "Date", "Évaluation courte"], ["Finir sans synthèse", "Imposer la même action", "Confondre satisfaction et apprentissage"]],
  ],
  M2_E7: [
    ["Participant qui conteste l’utilité", "Franchement, cet atelier ne sert à rien pour ma situation.", "contestataire", ["Accueillir le désaccord", "Faire préciser le besoin", "Relier ou adapter l’exercice à l’objectif"], ["Écoute", "Besoin", "Lien avec l’objectif", "Choix de participation"], ["Se justifier longuement", "Exclure immédiatement", "Promettre que tout sera utile"]],
    ["Tension entre deux participants", "Il me coupe tout le temps ! Je ne veux plus travailler avec lui.", "agacé", ["Stopper l’escalade", "Rappeler le cadre", "Permettre une reprise sécurisée de l’activité"], ["Pause", "Faits", "Règle", "Répartition", "Vérification"], ["Chercher un coupable", "Ignorer la tension", "Faire arbitrer le groupe"]],
    ["Consigne inaccessible", "Je n’ai pas compris l’exercice et je n’ose pas demander depuis tout à l’heure.", "gêné", ["Déculpabiliser", "Reformuler avec un exemple", "Vérifier la compréhension sans exposer la personne"], ["Accueil", "Consigne simple", "Démonstration", "Vérification", "Adaptation"], ["Répéter plus fort", "Faire à sa place", "Attribuer la difficulté à un manque de motivation"]],
    ["Clôture avec engagement fragile", "Oui, oui, je ferai tout ça plus tard.", "évasif", ["Éviter l’injonction", "Faire choisir une micro-action", "Préciser la date et le soutien utile"], ["Acquis", "Choix", "Micro-action", "Date", "Plan B"], ["Rendre une action obligatoire", "Multiplier les tâches", "Valider une réponse vague"]],
  ],
};

function employerSimulation(moduleId, index, definition) {
  const [title, startLine, tone, objectives, plan, pitfalls] = definition;
  return {
    actor: "employeur", duration: "10–12 min", title, startLine,
    persona: {
      id: `EMP_${moduleId}_${index + 1}`,
      role: "employeur ou responsable de recrutement",
      tone,
      reactions: {si_ecoute: "donne des éléments précis", si_promesse: "demande des garanties"},
    },
    briefing: {
      title, duration: "10–12 min", objectives, plan, pitfalls,
      notExpected: ["Promettre un résultat", "Décider à la place de l’employeur", "Transmettre des données sans accord"],
      starterPhrases: ["Pour bien comprendre, pouvez-vous me décrire une situation concrète ?", "Si je résume votre besoin…", "Je vous propose une prochaine étape simple et datée."],
    },
    tags: ["m3", "employeur", "rncp37274", moduleId.toLowerCase()],
    rubric: employerRubric,
    curriculumVersion: 2,
    contentStatus: "v2_corrected",
  };
}

function workshopSimulation(moduleId, index, definition) {
  const [title, startLine, tone, objectives, plan, pitfalls] = definition;
  return {
    actor: "beneficiaire", duration: "10–12 min", title, startLine,
    persona: {
      id: `ATELIER_${moduleId}_${index + 1}`,
      role: "participant à un atelier collectif",
      tone,
      reactions: {si_ecoute: "précise son besoin", si_injonction: "se ferme ou conteste"},
    },
    briefing: {
      title, duration: "10–12 min", objectives, plan, pitfalls,
      notExpected: ["Forcer la prise de parole", "Juger un participant", "Oublier l’objectif collectif"],
      starterPhrases: ["Je vous propose de préciser ce qui vous gêne.", "Je reformule la règle commune…", "Quelle petite action vous paraît possible à la fin de l’atelier ?"],
    },
    tags: ["m2", "atelier", "animation", moduleId.toLowerCase()],
    rubric: workshopRubric,
    curriculumVersion: 2,
    contentStatus: "v2_corrected",
  };
}

class Writer {
  constructor() { this.batch = db.batch(); this.count = 0; this.total = 0; }
  async set(ref, data, options = {merge: true}) {
    if (!APPLY) { this.total++; return; }
    this.batch.set(ref, data, options); this.count++; this.total++;
    if (this.count >= 400) await this.flush();
  }
  async flush() {
    if (!APPLY || this.count === 0) return;
    await this.batch.commit(); this.batch = db.batch(); this.count = 0;
  }
}

function questionSets(themes) {
  const easy = [], medium = [], expert = [];
  themes.forEach((theme, index) => {
    const [name, principle, situation, action, jury, reason] = theme;
    easy.push({question: `Concernant « ${name} », quel est le bon réflexe du CIP ?`, options: [principle, "Décider seul à la place des parties", "Promettre un résultat", "Reporter sans fixer de suite"], correctAnswer: 0, explanation: `${principle}. Cette pratique soutient une intervention professionnelle, traçable et centrée sur les besoins.`});
    medium.push({question: `Cas : ${situation}. Quelle action est la plus professionnelle ?`, options: ["Ne rien modifier", action, "Donner immédiatement une solution standard", "Transmettre la difficulté à un tiers sans accord"], correctAnswer: 1, explanation: `${action}. L’objectif est de partir des faits et de construire une réponse réaliste.`});
    expert.push({question: `Question du jury : « ${jury} » Quelle justification est la plus solide ?`, options: ["Parce que je fonctionne toujours ainsi", "Parce que cela rassure", reason, "Parce que l’employeur l’a demandé"], correctAnswer: 2, explanation: `${reason}. La justification relie l’action, son objectif et le cadre professionnel.`});
  });
  return {level_easy: easy, level_medium: medium, level_expert: expert};
}

async function main() {
  const writer = new Writer();
  const chapters = await db.collection("chapters").get();
  const knownCipChapters = new Set(["F0", "M1", "M2", "M3", "CERT"]);
  for (const chapterDoc of chapters.docs) {
    const chapterTrack = (chapterDoc.data().track || "").toString().trim();
    // Cette migration corrige uniquement le diplôme CIP. Elle ne doit jamais
    // réétiqueter les parcours NTC ou les futurs diplômes en RNCP37274.
    if (chapterTrack !== "cip" && !knownCipChapters.has(chapterDoc.id)) continue;
    const modules = await chapterDoc.ref.collection("modules").get();
    await writer.set(chapterDoc.ref, {curriculumVersion: 2, rncpReference: "RNCP37274", sourceTitle: "France Compétences — RNCP37274", sourceUrl: RNCP_URL});
    for (const moduleDoc of modules.docs) {
      const competency = competencyByModule[moduleDoc.id] || "RNCP37274 • À rattacher";
      const correction = moduleCorrections[moduleDoc.id];
      const moduleUpdate = {curriculumVersion: 2, rncpReference: "RNCP37274", rncpCompetency: competency, sourceTitle: "France Compétences — RNCP37274", sourceUrl: RNCP_URL};
      if (correction) [moduleUpdate.title, moduleUpdate.description] = correction;
      await writer.set(moduleDoc.ref, moduleUpdate);
      for (const collectionName of ["lessons", "simulations"]) {
        const docs = await moduleDoc.ref.collection(collectionName).get();
        for (const doc of docs.docs) {
          const data = doc.data();
          const update = {curriculumVersion: 2, rncpCompetency: competency, sourceTitle: "Référentiel RNCP37274", sourceUrl: RNCP_URL, contentStatus: "v2_structural_reviewed"};
          if (collectionName === "lessons") {
            const content = (data.content || "").toString().trim();
            if (content.length < 250) {
              update.content = `${content}${lessonExtensionByChapter[chapterDoc.id] || lessonExtensionByChapter.F0}`;
              update.contentStatus = "v2_expanded";
            }
          }
          if (collectionName === "simulations") {
            if (Object.prototype.hasOwnProperty.call(data, "rubric ")) {
              update["rubric "] = FieldValue.delete();
            }
            update.rubric = rubricFor(chapterDoc.id, moduleDoc.id, (data.actor || "").toString().toLowerCase());
            update.v2RecommendedDurationMinutes = 12;
          }
          await writer.set(doc.ref, update);
        }
      }
      const levels = await moduleDoc.ref.collection("levels").get();
      for (const levelDoc of levels.docs) {
        const questions = await levelDoc.ref.collection("questions").get();
        for (const questionDoc of questions.docs) {
          const data = questionDoc.data();
          const override = questionOverrides[questionDoc.ref.path];
          const update = {
            curriculumVersion: 2, rncpCompetency: competency,
            sourceTitle: "Référentiel RNCP37274", sourceUrl: RNCP_URL,
            contentStatus: override ? "v2_corrected" : "v2_structural_reviewed",
          };
          if (override) Object.assign(update, override);
          const explanation = (override?.explanation || data.explanation || "").toString().trim();
          if (explanation.length < 45) {
            update.explanation = `${explanation}${explanation ? " " : ""}${explanationSuffixByChapter[chapterDoc.id] || explanationSuffixByChapter.F0}`;
            update.contentStatus = override ? "v2_corrected" : "v2_explanation_expanded";
          }
          await writer.set(questionDoc.ref, update);
        }
      }
    }
  }

  for (const [moduleId, definitions] of Object.entries(m3EmployerSimulations)) {
    const simulationsRef = db.collection("chapters").doc("M3").collection("modules").doc(moduleId).collection("simulations");
    for (let i = 0; i < definitions.length; i++) {
      await writer.set(simulationsRef.doc(`${moduleId}_S${i + 1}`), employerSimulation(moduleId, i, definitions[i]), {merge: false});
    }
  }

  for (const [moduleId, definitions] of Object.entries(m2WorkshopSimulations)) {
    const simulationsRef = db.collection("chapters").doc("M2").collection("modules").doc(moduleId).collection("simulations");
    for (let i = 0; i < definitions.length; i++) {
      await writer.set(simulationsRef.doc(`${moduleId}_S${i + 1}`), workshopSimulation(moduleId, i, definitions[i]), {merge: false});
    }
  }

  for (const [moduleId, config] of Object.entries(v2Modules)) {
    const moduleRef = db.collection("chapters").doc("M3").collection("modules").doc(moduleId);
    await writer.set(moduleRef, {title: config.title, description: config.description, numberOfLessons: 3, numberOfLevels: 3, curriculumVersion: 2, rncpReference: "RNCP37274", rncpCompetency: competencyByModule[moduleId], sourceTitle: "France Compétences — RNCP37274", sourceUrl: RNCP_URL});
    for (const [id, title, content, order] of config.lessons) {
      await writer.set(moduleRef.collection("lessons").doc(id), {title, content, order, durationMinutes: 8, curriculumVersion: 2, rncpCompetency: competencyByModule[moduleId], sourceTitle: "Référentiel RNCP37274", sourceUrl: RNCP_URL, contentStatus: "v2_corrected"});
    }
    const sets = questionSets(config.themes);
    for (const [levelId, questions] of Object.entries(sets)) {
      const levelRef = moduleRef.collection("levels").doc(levelId);
      const order = levelId === "level_easy" ? 1 : levelId === "level_medium" ? 2 : 3;
      await writer.set(levelRef, {order, difficulty: levelId.replace("level_", ""), passingScore: 80});
      for (let i = 0; i < questions.length; i++) {
        await writer.set(levelRef.collection("questions").doc(`v2_${String(i + 1).padStart(2, "0")}`), {...questions[i], curriculumVersion: 2, rncpCompetency: competencyByModule[moduleId], sourceTitle: "Référentiel RNCP37274", sourceUrl: RNCP_URL, contentStatus: "v2_corrected"});
      }
    }
  }

  await writer.set(db.collection("app_config").doc("exam_v2"), {
    rncpReference: "RNCP37274", preparationMinutes: 15, interviewMinutes: 30,
    writingMinutes: 20, totalExamMinutes: 175, sourceUrl: RNCP_URL,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await writer.flush();
  console.log(`${APPLY ? "Migration appliquée" : "Simulation uniquement"}: ${writer.total} écritures prévues.`);
  if (!APPLY) console.log("Relancer avec --apply après vérification.");
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
