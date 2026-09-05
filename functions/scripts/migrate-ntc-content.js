"use strict";

const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

initializeApp({credential: applicationDefault(), projectId: "emploiboost"});
const db = getFirestore();
const APPLY = process.argv.includes("--apply");
const TRACK = "ntc";
const RNCP = "RNCP39063";
const RNCP_URL = "https://www.francecompetences.fr/recherche/rncp/39063/";
const DIPLOMA = "Négociateur technico-commercial";

const chapters = [
  {
    id: "NTC_BC1",
    order: 1,
    title: "CCP 1 • Stratégie et prospection",
    description: "Construire une stratégie, prospecter un secteur et piloter la performance commerciale.",
  },
  {
    id: "NTC_BC2",
    order: 2,
    title: "CCP 2 • Négociation et expérience client",
    description: "Concevoir, négocier et suivre une solution technique et commerciale rentable.",
  },
  {
    id: "NTC_CERT",
    order: 3,
    title: "Certification • RNCP39063",
    description: "Maîtriser l’étude de cas, les productions, les oraux, la SWOT et l’entretien final.",
  },
];

const modules = [
  {
    chapter: "NTC_BC1", id: "NTC_BC1_M1", order: 1,
    title: "1. Assurer une veille commerciale utile",
    description: "Transformer des sources fiables en décisions de ciblage et d’argumentation.",
    competency: "RNCP39063BC01 • Assurer une veille commerciale",
    actor: "manager commercial",
    lessons: [
      ["Définir une veille orientée décision", "Une veille commerciale n’est pas une accumulation de liens. Elle part d’une décision à préparer : sélectionner un segment, anticiper une objection, détecter un investissement ou repositionner une offre. Le commercial définit les thèmes, les sources, la fréquence et le destinataire de la synthèse. Il distingue une information vérifiée d’un signal à confirmer, date les données et conserve leur origine. La production attendue se termine par une conséquence opérationnelle : cible à tester, risque à surveiller, argument à adapter ou action à proposer."],
      ["Analyser marché, concurrence et processus d’achat", "L’analyse croise la taille et la dynamique du marché, les tendances réglementaires, les offres concurrentes, les critères de choix et le processus d’investissement des entreprises. Une fiche concurrent utile compare des faits : cible, promesse, périmètre, preuve, prix connu, conditions et limites. Le NTC relie ensuite ces éléments au profil client idéal. Il évite les conclusions générales et formule des hypothèses testables lors des prochains échanges commerciaux."],
      ["Présenter une synthèse qui fait agir", "Une synthèse professionnelle tient sur une structure simple : objectif, trois faits majeurs, opportunités, menaces, impact commercial et recommandation. Chaque recommandation indique un responsable, une échéance et un indicateur. Devant le jury, le candidat doit expliquer pourquoi la source est crédible, comment il a recoupé l’information et quelle décision a changé. La qualité ne se mesure donc pas au nombre de pages, mais à la traçabilité et à l’utilité pour l’action."],
    ],
    themes: [
      ["objectif de veille", "partir d’une décision commerciale à préparer", "Votre veille contient beaucoup d’articles mais aucune priorité.", "reformuler la question de veille et relier chaque information à une décision", "Pourquoi avez-vous retenu cette information ?", "elle modifie une cible, un risque, un argument ou une action"],
      ["fiabilité des sources", "dater, recouper et citer l’origine des données", "Un chiffre intéressant circule sur un réseau social sans source identifiable.", "le traiter comme un signal et chercher une source primaire ou convergente", "Comment prouvez-vous la fiabilité de votre chiffre ?", "la date, l’auteur, la méthode et le recoupement sont vérifiables"],
      ["analyse concurrentielle", "comparer des critères identiques et factuels", "L’équipe affirme seulement que le concurrent est moins cher.", "comparer périmètre, valeur, preuves, prix et conditions sur une même grille", "Pourquoi votre benchmark est-il exploitable ?", "il évite les impressions et fait apparaître les écarts réellement négociables"],
      ["signal d’affaires", "transformer une évolution en hypothèse de besoin", "Une nouvelle réglementation touche un segment de prospects.", "mesurer l’impact probable et préparer des questions de qualification", "Pourquoi ne lancez-vous pas immédiatement une campagne massive ?", "le signal doit être confirmé avant d’engager les moyens commerciaux"],
      ["diffusion de la veille", "adapter la synthèse au destinataire et proposer une action", "Le rapport mensuel n’est lu par personne.", "réduire la synthèse, hiérarchiser les faits et conclure par une décision attendue", "Quelle valeur votre veille apporte-t-elle au manager ?", "elle permet d’arbitrer une action avec des éléments traçables"],
    ],
  },
  {
    chapter: "NTC_BC1", id: "NTC_BC1_M2", order: 2,
    title: "2. Concevoir un plan d’actions commerciales",
    description: "Passer du diagnostic aux objectifs, cibles, moyens, calendrier et indicateurs.",
    competency: "RNCP39063BC01 • Concevoir et organiser un plan d’actions commerciales",
    actor: "directeur commercial",
    lessons: [
      ["Du diagnostic aux objectifs SMART", "Le plan d’actions commence par un écart précis entre la situation actuelle et la situation attendue. Le NTC hiérarchise les enjeux selon leur impact, leur urgence et leur maîtrise possible. Il transforme ensuite les priorités en objectifs SMART : résultat mesurable, cible définie, échéance et niveau attendu. Un objectif comme développer les ventes devient, par exemple, obtenir quinze rendez-vous qualifiés sur le segment des PME industrielles en huit semaines avec un taux de transformation suivi."],
      ["Orchestrer cibles, canaux et ressources", "Chaque action précise la cible, la proposition de valeur, le canal, la séquence, le responsable, le budget, la date et l’indicateur. Le téléphone, l’e-mail, le social selling, les événements et le terrain ne sont pas opposés : ils sont combinés selon le comportement de la cible. Le calendrier tient compte des capacités réelles de l’équipe, des délais de décision et des dépendances internes. Les hypothèses critiques et les plans de repli sont explicités."],
      ["Faire du PAC un outil de pilotage", "Le PAC est revu à intervalles courts. Un rituel de pilotage compare le prévu, le réalisé et l’écart, puis décide d’une action. Le NTC distingue les indicateurs d’activité, de qualité, de conversion et de résultat. Il ne change pas toute la stratégie après une semaine : il teste une variable à la fois, conserve une base de comparaison et documente l’apprentissage. Devant le jury, chaque moyen doit être justifié par le diagnostic et chaque KPI par l’objectif."],
    ],
    themes: [
      ["diagnostic commercial", "quantifier l’écart avant de choisir les actions", "Le chiffre d’affaires baisse mais aucune cause n’est analysée.", "segmenter les résultats et identifier où se crée l’écart", "Pourquoi commencez-vous par le diagnostic ?", "une action pertinente répond à une cause objectivée et non à une impression"],
      ["objectif SMART", "définir résultat, cible, mesure et échéance", "L’objectif annoncé est de prospecter davantage.", "le traduire en rendez-vous qualifiés, segment, volume et délai", "Qu’est-ce qui rend votre objectif pilotable ?", "le résultat attendu et sa mesure sont compris de tous"],
      ["choix des canaux", "adapter le canal au segment et au moment du parcours", "La même séquence e-mail est envoyée à tous les prospects.", "différencier la séquence selon le rôle, la maturité et les usages", "Pourquoi utilisez-vous plusieurs canaux ?", "la combinaison augmente la pertinence sans multiplier les contacts inutiles"],
      ["allocation des moyens", "vérifier charge, budget, compétences et dépendances", "Le PAC prévoit cent visites sans temps de déplacement.", "recalculer la capacité et arbitrer les cibles prioritaires", "Votre plan est-il réellement faisable ?", "les moyens et les contraintes sont cohérents avec l’objectif"],
      ["gouvernance du PAC", "dater les revues et décider à partir des écarts", "Le plan est présenté puis n’est plus suivi pendant trois mois.", "installer un rituel court avec décision, responsable et échéance", "Comment évitez-vous un PAC purement théorique ?", "chaque revue transforme un écart en action suivie"],
    ],
  },
  {
    chapter: "NTC_BC1", id: "NTC_BC1_M3", order: 3,
    title: "3. Prospecter un secteur défini",
    description: "Segmenter, contacter, qualifier et obtenir une prochaine étape utile.",
    competency: "RNCP39063BC01 • Prospecter un secteur défini",
    actor: "prospect B2B",
    lessons: [
      ["Construire un ciblage qui économise l’effort", "Le NTC définit son profil client idéal à partir de critères observables : secteur, taille, implantation, équipement, déclencheur, enjeu et capacité de décision. Il identifie ensuite les fonctions impliquées et leur intérêt spécifique. La qualité d’une liste ne dépend pas seulement du nombre de contacts : elle dépend de la correspondance avec l’offre, de l’actualité du besoin et de la possibilité d’atteindre le décideur. Les données sont collectées et utilisées dans un cadre professionnel et proportionné."],
      ["Écrire une séquence multicanale centrée sur le prospect", "Une accroche efficace relie un fait concernant le prospect à une conséquence métier et ouvre une question. Elle évite la longue présentation de l’entreprise. La séquence alterne des contacts utiles, espacés et cohérents : appel, message personnalisé, contenu de preuve, relance et clôture propre. Chaque prise de contact apporte une information nouvelle. Le NTC prépare les barrages, les objections de premier niveau et une demande de prochaine étape simple."],
      ["Qualifier avant de compter un rendez-vous", "Un rendez-vous est qualifié lorsque le problème, l’enjeu, les acteurs, le calendrier et la prochaine étape sont suffisamment compris. Le commercial ne force pas une démonstration à un prospect sans besoin. Il reformule, confirme les informations manquantes et consigne le résultat dans le CRM. Les indicateurs suivent la joignabilité, les conversations utiles, les rendez-vous qualifiés et la conversion par segment afin d’améliorer la séquence."],
    ],
    themes: [
      ["profil client idéal", "sélectionner des critères liés à la valeur de l’offre", "La liste contient toutes les entreprises d’un département sans priorité.", "noter les comptes selon adéquation, signal d’affaires et accessibilité", "Pourquoi excluez-vous certains comptes ?", "la concentration des moyens augmente la probabilité d’un besoin réel"],
      ["accroche", "parler d’un enjeu probable avant de présenter l’entreprise", "Le prospect interrompt une présentation de deux minutes.", "utiliser un fait pertinent, une conséquence et une question courte", "Pourquoi votre accroche est-elle personnalisée ?", "elle donne immédiatement une raison professionnelle de poursuivre"],
      ["barrage", "respecter l’interlocuteur et rechercher la bonne orientation", "L’assistante demande l’objet exact de votre appel.", "formuler la valeur, vérifier la fonction visée et demander le canal adapté", "Comment franchissez-vous un barrage sans manipulation ?", "la clarté et le respect protègent la relation avec l’entreprise"],
      ["qualification", "valider enjeu, acteurs, calendrier et prochaine étape", "Le prospect accepte un rendez-vous mais ne formule aucun besoin.", "poser quelques questions de contexte avant de confirmer le rendez-vous", "Pourquoi ne comptez-vous pas tous les rendez-vous de la même façon ?", "un rendez-vous qualifié a une finalité et des conditions de réussite"],
      ["traçabilité CRM", "enregistrer faits, source, statut et prochaine action", "Les notes indiquent seulement prospect intéressé.", "consigner les mots clés du besoin, les personnes et une date de relance", "À quoi sert votre traçabilité ?", "elle permet la continuité, la mesure et une relance pertinente"],
    ],
  },
  {
    chapter: "NTC_BC1", id: "NTC_BC1_M4", order: 4,
    title: "4. Analyser les performances et corriger",
    description: "Lire un funnel, expliquer les écarts et tester des actions correctives.",
    competency: "RNCP39063BC01 • Analyser ses performances et mettre en œuvre des actions correctives",
    actor: "responsable des ventes",
    lessons: [
      ["Lire le funnel sans confondre activité et résultat", "Le tableau de bord relie les volumes à chaque étape : comptes ciblés, contacts, conversations, rendez-vous qualifiés, propositions, négociations, ventes et marge. Le NTC calcule les taux de passage, la durée du cycle et la valeur moyenne. Un grand nombre d’appels n’est pas une performance si la cible est mauvaise ou si aucune conversation utile n’en résulte. Les indicateurs sont analysés par segment, canal et période comparable."],
      ["Rechercher la cause racine d’un écart", "Un écart peut venir du ciblage, de la donnée, du message, de la compétence, du processus, de l’offre ou du contexte. Le NTC formule plusieurs hypothèses et recherche des preuves : écoute d’appels, motifs de perte, comparaison des segments, délai de réponse ou retours clients. Il distingue ce qu’il contrôle de ce qu’il doit signaler. Une cause n’est retenue que si elle explique les données mieux que les alternatives."],
      ["Conduire une action corrective mesurable", "Une action corrective précise l’hypothèse, le changement, le périmètre du test, la durée, l’indicateur et le seuil de décision. Elle évite de modifier simultanément la cible, le message et le prix, car le résultat deviendrait impossible à interpréter. Le NTC partage le bilan, les limites et la recommandation. Si le test échoue, il capitalise l’apprentissage au lieu de masquer l’écart."],
    ],
    themes: [
      ["taux de conversion", "calculer le passage entre deux étapes comparables", "Les rendez-vous augmentent mais les propositions diminuent.", "calculer les taux par segment et vérifier la qualification des rendez-vous", "Pourquoi le volume seul ne suffit-il pas ?", "le taux révèle l’étape où la valeur se perd"],
      ["marge", "suivre la valeur rentable et pas seulement le chiffre d’affaires", "Les ventes progressent grâce à des remises très fortes.", "comparer marge, remise et coût d’acquisition avant de conclure", "Votre résultat est-il réellement positif ?", "une vente non rentable peut dégrader la performance globale"],
      ["cause racine", "tester plusieurs hypothèses avec des preuves", "L’équipe attribue immédiatement l’échec au prix.", "analyser motifs de perte, ciblage, découverte et comparaison concurrentielle", "Pourquoi refusez-vous l’explication la plus évidente ?", "une corrélation ou une opinion ne démontre pas la cause"],
      ["action corrective", "modifier une variable et définir un seuil de réussite", "Trois changements sont lancés le même jour.", "isoler le test, sa durée et l’indicateur principal", "Comment saurez-vous ce qui a fonctionné ?", "un test interprétable conserve une base de comparaison"],
      ["reporting", "présenter faits, analyse, décision, risque et prochaine revue", "Le compte rendu masque les objectifs non atteints.", "expliquer l’écart et proposer une action suivie", "Comment rendez-vous compte sans vous justifier ?", "la transparence transforme l’écart en décision managériale"],
    ],
  },
  {
    chapter: "NTC_BC2", id: "NTC_BC2_M1", order: 1,
    title: "1. Représenter l’entreprise et sa valeur",
    description: "Installer une confiance professionnelle cohérente sur tous les points de contact.",
    competency: "RNCP39063BC02 • Représenter l’entreprise et valoriser son image",
    actor: "client exigeant",
    lessons: [
      ["Porter une promesse crédible", "Représenter l’entreprise consiste à traduire sa stratégie, ses engagements et ses limites dans chaque interaction. Le NTC connaît le périmètre de l’offre, les preuves disponibles et les règles qu’il ne peut pas modifier seul. Il adapte le niveau technique à l’interlocuteur sans exagérer. La confiance repose sur la cohérence entre ce qui est annoncé, écrit, livré et suivi."],
      ["Adapter la communication au canal et à la personne", "Le rendez-vous, l’e-mail, le réseau social et le téléphone ont des codes différents mais doivent conserver le même professionnalisme. Le NTC prépare des supports lisibles, accessibles et sobres, vérifie la compréhension et tient compte d’éventuels besoins d’adaptation. Il utilise les données du client uniquement pour la finalité commerciale annoncée et évite les pratiques intrusives."],
      ["Coordonner la réponse de l’entreprise", "Le commercial ne travaille pas seul. Il sécurise les informations avec les équipes techniques, juridiques, financières et opérationnelles. Il ne promet pas un délai ou une fonctionnalité non validés. Lorsqu’une erreur survient, il la reconnaît, explique ce qui est vérifié et fixe une date de retour. Cette posture protège la réputation et donne au client un interlocuteur fiable."],
    ],
    themes: [
      ["promesse", "annoncer uniquement une valeur et des conditions vérifiées", "Le prospect demande une fonctionnalité encore incertaine.", "indiquer ce qui est confirmé et dater la vérification du reste", "Pourquoi ne répondez-vous pas immédiatement oui ?", "la crédibilité vaut mieux qu’une promesse impossible à tenir"],
      ["preuve", "relier chaque bénéfice important à un élément démontrable", "La présentation affirme que la solution est la meilleure du marché.", "remplacer le superlatif par un résultat, une référence ou une démonstration", "Comment rendez-vous votre argument crédible ?", "une preuve contextualisée permet au client d’évaluer la valeur"],
      ["accessibilité", "adapter le support et vérifier la compréhension", "Un décideur signale une difficulté avec le document transmis.", "proposer un format accessible sans supposer son besoin exact", "Pourquoi adaptez-vous votre communication ?", "chaque interlocuteur doit pouvoir participer réellement à la décision"],
      ["coordination interne", "faire valider les engagements hors délégation", "Le client exige un délai très court.", "consulter l’équipe responsable avant de confirmer", "Cela ne ralentit-il pas la vente ?", "un engagement réaliste sécurise la signature et l’expérience client"],
      ["incident", "reconnaître les faits et organiser une réponse datée", "Une information erronée figure dans la proposition.", "corriger, expliquer l’impact et confirmer la version de référence", "Comment protégez-vous l’image dans une difficulté ?", "la transparence et la maîtrise de la suite restaurent la confiance"],
    ],
  },
  {
    chapter: "NTC_BC2", id: "NTC_BC2_M2", order: 2,
    title: "2. Concevoir une proposition technique et commerciale",
    description: "Passer de la découverte à une solution faisable, rentable et différenciante.",
    competency: "RNCP39063BC02 • Concevoir une proposition technique et commerciale",
    actor: "décideur B2B",
    lessons: [
      ["Conduire une découverte à plusieurs niveaux", "La découverte explore la situation actuelle, les irritants, les impacts, les objectifs, les critères de décision, les acteurs, le budget, le calendrier et les risques. Le NTC distingue ce que le client demande de ce dont il a besoin pour atteindre son résultat. Il quantifie quand cela est possible et reformule pour validation. Il identifie aussi le processus d’achat et les personnes qui utiliseront, financeront ou valideront la solution."],
      ["Construire une solution faisable et rentable", "La solution traduit chaque besoin prioritaire en composant technique ou service, bénéfice attendu et preuve. Le NTC vérifie la capacité de livraison, les dépendances, les coûts, la marge, les conditions et les enjeux écologiques. Il prépare plusieurs options uniquement si elles aident à décider. Les hypothèses, exclusions et responsabilités sont explicites afin d’éviter les malentendus après la signature."],
      ["Rédiger une proposition qui facilite la décision", "Une proposition efficace rappelle le contexte validé, les objectifs, la solution, le périmètre, le planning, les engagements, le prix, les conditions et la prochaine étape. Elle hiérarchise l’information pour les différents lecteurs. Le prix est relié à la valeur et au périmètre, pas dissimulé. Avant envoi, le NTC réalise une revue de cohérence technique, commerciale, juridique et rédactionnelle."],
    ],
    themes: [
      ["besoin implicite", "faire préciser les conséquences et le résultat attendu", "Le client demande seulement un devis standard.", "questionner l’usage, l’impact et les critères de réussite", "Pourquoi poursuivez-vous la découverte ?", "la demande initiale ne décrit pas toujours le problème à résoudre"],
      ["circuit de décision", "identifier utilisateurs, prescripteurs, financeurs et décideur", "Le contact apprécie la solution mais ne peut pas engager l’entreprise.", "cartographier les rôles et convenir d’une validation avec les acteurs utiles", "Pourquoi élargissez-vous les interlocuteurs ?", "une proposition doit répondre aux critères de toutes les fonctions décisives"],
      ["faisabilité", "faire valider capacités, délais et dépendances", "Une option technique semble attractive mais n’a jamais été livrée.", "obtenir une validation interne et formuler les conditions", "Pourquoi mentionnez-vous les hypothèses ?", "elles délimitent l’engagement et préviennent une promesse irréaliste"],
      ["rentabilité", "calculer coûts, marge et impact des conditions", "Le prospect demande un périmètre supplémentaire au même prix.", "recalculer la marge et proposer un arbitrage de périmètre ou de prix", "Pourquoi ne cherchez-vous pas seulement à signer ?", "la vente doit créer une valeur durable pour les deux entreprises"],
      ["structure de l’offre", "relier besoin, solution, bénéfice, preuve et condition", "Le document présente vingt caractéristiques sans priorité.", "organiser l’offre autour des enjeux validés du client", "Comment facilitez-vous la décision ?", "le lecteur retrouve le lien entre son problème et la solution proposée"],
    ],
  },
  {
    chapter: "NTC_BC2", id: "NTC_BC2_M3", order: 3,
    title: "3. Négocier une solution commerciale",
    description: "Préparer les marges, défendre la valeur et obtenir un accord équilibré.",
    competency: "RNCP39063BC02 • Négocier une solution technique et commerciale",
    actor: "acheteur professionnel",
    lessons: [
      ["Préparer objectifs, limites et alternatives", "Avant le rendez-vous, le NTC définit son objectif cible, son minimum acceptable et son alternative en cas de non-accord. Il liste les variables négociables : prix, volume, durée, délai, services, paiement, référence ou calendrier. Chaque concession a un coût et appelle une contrepartie. Il anticipe les pouvoirs de décision, les objections probables et les preuves à mobiliser."],
      ["Conduire la négociation sans perdre la découverte", "Le NTC ouvre le rendez-vous en validant l’agenda et les critères de décision. Il actualise la découverte, présente une recommandation, vérifie les réactions et traite les objections. Une objection est clarifiée avant d’être répondue. Il défend la valeur avec des impacts et des preuves, garde les silences utiles et ne baisse pas le prix pour soulager une tension. La relation reste ferme sur le fond et respectueuse sur la forme."],
      ["Conclure et sécuriser l’accord", "Une négociation réussie se termine par des termes compris et traçables : périmètre, prix, contreparties, responsabilités, calendrier, conditions et prochaine étape. Le NTC vérifie l’autorité de signature et reformule les points en suspens. Si l’accord n’est pas possible, il fixe une condition de reprise ou clôt proprement. Il transmet ensuite les engagements aux équipes concernées."],
    ],
    themes: [
      ["zone de négociation", "définir cible, minimum et alternative avant l’entretien", "Le client demande une remise dès le début.", "revenir aux critères de valeur avant d’utiliser une marge préparée", "Pourquoi préparez-vous un minimum acceptable ?", "il évite une décision improvisée sous pression"],
      ["objection", "clarifier la nature et le poids réel du frein", "Le client dit simplement que la solution est trop chère.", "faire préciser la comparaison, le budget et la valeur manquante", "Pourquoi ne répondez-vous pas immédiatement au prix ?", "la première formulation peut masquer un doute, un risque ou une tactique"],
      ["concession", "échanger toute concession significative contre une contrepartie", "L’acheteur demande dix pour cent de remise.", "conditionner l’effort à un volume, une durée ou une modalité utile", "Pourquoi demandez-vous une contrepartie ?", "elle protège la valeur et teste la réalité de l’engagement"],
      ["argumentation", "relier la solution à un impact prioritaire et prouvé", "Le décideur ne réagit pas à la liste des fonctionnalités.", "revenir à l’enjeu quantifié et illustrer le résultat attendu", "Qu’est-ce qu’un argument personnalisé ?", "il associe une caractéristique utile à la situation précise du client"],
      ["conclusion", "reformuler tous les accords et les prochaines responsabilités", "Le client donne un accord verbal mais plusieurs points restent flous.", "formaliser périmètre, conditions, décideurs et calendrier", "Pourquoi ne considérez-vous pas la vente comme terminée ?", "un accord non précisé crée des risques de livraison et de satisfaction"],
    ],
  },
  {
    chapter: "NTC_BC2", id: "NTC_BC2_M4", order: 4,
    title: "4. Réaliser le bilan et rendre compte",
    description: "Suivre l’exécution, mesurer la valeur et ajuster l’activité commerciale.",
    competency: "RNCP39063BC02 • Réaliser le bilan, ajuster son activité et rendre compte",
    actor: "manager commercial",
    lessons: [
      ["Préparer le passage de la vente à la réalisation", "Après l’accord, le NTC organise une transmission structurée : contexte, objectifs du client, périmètre, engagements, risques, interlocuteurs, calendrier et critères de réussite. Il vérifie que les équipes comprennent ce qui a été vendu. Un point de lancement avec le client confirme les responsabilités et les canaux. Cette étape réduit l’écart entre la promesse commerciale et l’expérience réelle."],
      ["Mesurer le résultat commercial et client", "Le bilan combine chiffre d’affaires, marge, durée du cycle, coût commercial, respect des engagements, adoption, satisfaction et incidents. Le NTC compare les résultats aux objectifs et recueille des faits auprès du client et des équipes. Il distingue un problème de vente, de livraison, d’usage ou de coordination. Le compte rendu présente les résultats, les écarts, les causes probables et les décisions proposées."],
      ["Transformer le retour d’expérience en amélioration", "Le NTC choisit une amélioration prioritaire et observable : question de découverte, modèle d’offre, validation interne, séquence de suivi ou indicateur CRM. Il désigne le responsable et la date de vérification. Il partage également les enseignements utiles à l’offre ou au marketing. Rendre compte ne consiste pas à se justifier, mais à aider l’entreprise à arbitrer avec une information honnête et structurée."],
    ],
    themes: [
      ["transmission", "partager engagements, risques et critères de réussite", "L’équipe opérationnelle découvre une option promise au client.", "organiser une revue d’accord avant le lancement", "Pourquoi intervenez-vous après la signature ?", "la continuité entre vente et livraison conditionne la satisfaction"],
      ["bilan économique", "comparer revenu, marge et coûts réellement engagés", "Le contrat est présenté comme un succès malgré de nombreux travaux non prévus.", "recalculer la rentabilité et identifier l’origine des écarts", "Pourquoi analysez-vous les coûts après la vente ?", "le retour d’expérience améliore les futurs chiffrages et décisions"],
      ["satisfaction", "recueillir des faits à des moments clés", "Le client ne se plaint pas et l’équipe suppose qu’il est satisfait.", "questionner l’atteinte des objectifs, l’usage et les irritants", "L’absence de réclamation suffit-elle ?", "un silence ne mesure ni la valeur perçue ni le risque de départ"],
      ["compte rendu", "séparer résultats, analyse, décision et demande d’arbitrage", "Le reporting contient uniquement une chronologie détaillée.", "synthétiser les écarts et proposer les décisions nécessaires", "Qu’attendez-vous du destinataire ?", "un bon reporting permet d’agir rapidement"],
      ["amélioration continue", "définir une action mesurable issue du bilan", "La conclusion indique seulement mieux préparer les prochaines ventes.", "nommer la pratique à modifier, le responsable, la date et l’indicateur", "Comment prouvez-vous que le bilan sert ?", "la décision est suivie jusqu’à l’observation de son effet"],
    ],
  },
  {
    chapter: "NTC_BC2", id: "NTC_BC2_M5", order: 5,
    title: "5. Optimiser la relation et l’expérience client",
    description: "Fiabiliser le CRM, prévenir les risques et développer la valeur dans la durée.",
    competency: "RNCP39063BC02 • Optimiser la gestion de la relation client",
    actor: "client stratégique",
    lessons: [
      ["Faire du CRM une mémoire exploitable", "Une donnée CRM utile est exacte, datée, proportionnée et orientée vers une action. Le NTC renseigne les interlocuteurs, les besoins validés, les décisions, les engagements, les risques, les opportunités et la prochaine étape. Il évite les jugements sur les personnes et respecte les règles de l’entreprise concernant les données. Les étapes et motifs de perte sont définis de façon commune pour rendre les analyses comparables."],
      ["Piloter l’expérience et la fidélisation", "La fidélisation commence avant la signature par des attentes réalistes. Le NTC organise des points adaptés au cycle du client : lancement, adoption, résultat, renouvellement. Il repère les signaux faibles comme la baisse d’usage, les retards, les interlocuteurs absents ou les incidents répétés. Il traite d’abord la valeur promise avant de proposer une vente complémentaire."],
      ["Développer le compte sans forcer", "Une opportunité d’extension part d’un besoin nouveau, d’un résultat acquis ou d’une évolution du client. Le NTC cartographie les acteurs, partage un bilan de valeur et explore la suite. En cas de réclamation, il recueille les faits, reconnaît l’impact, coordonne la résolution et confirme la clôture. La qualité de la relation se mesure à la confiance, à la valeur créée et à la capacité de traiter les difficultés."],
    ],
    themes: [
      ["qualité CRM", "saisir des faits datés et une prochaine action", "Une fiche client contient des commentaires vagues et aucun suivi.", "nettoyer les données et définir le prochain contact utile", "Pourquoi standardisez-vous certaines informations ?", "des données comparables rendent le suivi et le pilotage fiables"],
      ["signal faible", "agir avant que l’insatisfaction ne devienne une rupture", "L’utilisateur clé ne participe plus aux points de suivi.", "vérifier l’usage, les obstacles et l’évolution des priorités", "Pourquoi contactez-vous un client qui ne se plaint pas ?", "une baisse d’engagement peut annoncer une perte de valeur"],
      ["réclamation", "recueillir les faits, reconnaître l’impact et dater la résolution", "Le client signale un écart important avec l’engagement.", "coordonner le traitement et confirmer chaque étape", "Faut-il chercher immédiatement un responsable ?", "la priorité est de sécuriser la situation et la confiance"],
      ["fidélisation", "démontrer la valeur obtenue avant de parler renouvellement", "Le contrat arrive à échéance sans bilan partagé.", "préparer les résultats, les écarts et les objectifs futurs", "Pourquoi anticiper le renouvellement ?", "la décision se prépare sur des preuves et non dans l’urgence"],
      ["développement de compte", "relier l’extension à un besoin ou résultat nouveau", "Le manager demande de vendre une option à tous les clients.", "sélectionner les comptes pour lesquels l’option crée une valeur démontrable", "Pourquoi ne proposez-vous pas l’option systématiquement ?", "une recommandation pertinente protège la confiance et la rentabilité"],
    ],
  },
  {
    chapter: "NTC_CERT", id: "NTC_CERT_E1", order: 1,
    title: "1. Étude de cas, tableau de bord et PAC",
    description: "Produire une analyse chiffrée et un plan défendable sous contrainte de temps.",
    competency: "Certification • Mise en situation écrite RNCP39063",
    actor: "jury NTC",
    lessons: [
      ["Décoder le sujet avant de produire", "Le candidat commence par repérer les livrables, les données disponibles, les informations manquantes et les contraintes. Il construit une feuille de route du temps et réserve une phase de contrôle. Chaque calcul est nommé, chaque hypothèse est signalée et chaque recommandation se rattache à un résultat. Cette lecture évite de rédiger beaucoup sans répondre à la commande."],
      ["Du tableau de bord aux 10 à 12 diapositives", "La présentation suit une logique décisionnelle : contexte, résultats, écarts, causes, priorité, objectifs, actions, moyens, calendrier, KPI, risques et décision attendue. Les diapositives ne recopient pas le tableau. Elles font apparaître les chiffres qui justifient l’action. Le candidat prépare aussi ce qu’il dira et les questions probables du jury."],
      ["Contrôler la cohérence en temps limité", "Avant de rendre, le candidat vérifie unités, périodes, totaux, taux, objectifs et faisabilité. Il s’assure que les cibles du PAC répondent au diagnostic et que les indicateurs mesurent bien les objectifs. Il relit les titres comme un résumé autonome. Une production légèrement plus courte mais cohérente et défendable vaut mieux qu’un document dense et contradictoire."],
    ],
    themes: [
      ["commande", "identifier tous les livrables avant de calculer", "Le candidat découvre à la fin qu’un plan d’actions était demandé.", "dresser la liste des productions et répartir le temps", "Pourquoi formaliser votre feuille de route ?", "elle sécurise la complétude sous contrainte"],
      ["calcul", "nommer formule, période et unité", "Deux taux différents sont comparés sans préciser leur base.", "recalculer sur des dénominateurs comparables", "Comment le jury vérifie-t-il votre résultat ?", "la méthode et les données utilisées sont explicites"],
      ["priorité", "retenir l’écart ayant le plus d’impact et de maîtrise", "La présentation traite dix problèmes avec la même importance.", "hiérarchiser et justifier une priorité commerciale", "Pourquoi ne traitez-vous pas tout ?", "un plan réaliste concentre les moyens sur les leviers principaux"],
      ["diaporama", "faire de chaque titre une conclusion utile", "Les diapositives portent des titres comme Résultats ou Actions.", "rédiger un message clé chiffré dans le titre", "Votre support peut-il être compris sans votre voix ?", "la structure rend le raisonnement visible"],
      ["contrôle", "réserver du temps pour cohérence et forme", "Un objectif ne correspond pas au KPI présenté.", "relire la chaîne diagnostic, objectif, action et mesure", "Que vérifiez-vous avant de rendre ?", "chaque décision doit être soutenue par les mêmes données"],
    ],
  },
  {
    chapter: "NTC_CERT", id: "NTC_CERT_E2", order: 2,
    title: "2. Appel de prospection et négociation",
    description: "Obtenir un rendez-vous puis défendre une proposition commerciale complète.",
    competency: "Certification • Appel de 15 min et négociation de 60 min",
    actor: "jury jouant le prospect",
    lessons: [
      ["Réussir l’appel évalué", "L’appel doit identifier le bon interlocuteur, présenter une raison pertinente, susciter l’intérêt et obtenir une prochaine étape. Le candidat reste naturel et écoute les réponses. Il ne récite pas un script long. Il prépare l’objet de l’appel, deux questions de qualification, une preuve courte, les barrages possibles et une formulation précise du rendez-vous."],
      ["Tenir une négociation de soixante minutes", "L’oral long exige une progression : cadrage, actualisation de la découverte, reformulation, recommandation, argumentation, objections, négociation et conclusion. Le candidat utilise sa proposition écrite sans la lire. Il montre qu’il comprend les enjeux techniques, économiques et relationnels. Les concessions sont préparées et les engagements sont reformulés."],
      ["Produire des preuves observables", "Le jury évalue ce que le candidat fait et explique. Une bonne intention non visible ne suffit pas. Le candidat formule ses questions, résume les réponses, annonce sa logique, vérifie l’accord et note les décisions. Lors du questionnement, il s’appuie sur des moments précis de l’échange, reconnaît les informations manquantes et propose une amélioration concrète."],
    ],
    themes: [
      ["prise de rendez-vous", "proposer objet, durée, participants et bénéfice du prochain échange", "Le prospect accepte vaguement de reparler plus tard.", "fixer une date ou une modalité de confirmation précise", "Pourquoi votre appel est-il réussi ?", "une prochaine étape claire et pertinente est obtenue"],
      ["agenda de négociation", "valider objectifs et étapes du rendez-vous", "Le candidat commence immédiatement sa présentation.", "cadrer l’échange et vérifier les attentes du décideur", "Pourquoi consacrer du temps au cadrage ?", "il aligne les priorités et permet d’adapter la suite"],
      ["écoute", "reformuler les informations nouvelles avant d’argumenter", "Le client modifie un besoin important pendant l’oral.", "mettre à jour le diagnostic et ajuster la proposition", "Comment prouvez-vous votre capacité d’adaptation ?", "la recommandation évolue à partir d’un fait exprimé"],
      ["négociation", "utiliser une concession conditionnelle et traçable", "Le jury demande une remise importante.", "explorer la raison puis échanger l’effort contre une contrepartie", "Quelle marge de manœuvre aviez-vous ?", "elle était préparée avec son coût et ses conditions"],
      ["auto-analyse", "citer un fait, son effet et une amélioration", "Le candidat affirme seulement que l’entretien s’est bien passé.", "prendre un moment précis et analyser son impact", "Quel élément modifieriez-vous ?", "une amélioration crédible part d’une preuve observable"],
    ],
  },
  {
    chapter: "NTC_CERT", id: "NTC_CERT_E3", order: 3,
    title: "3. SWOT, productions et entretien final",
    description: "Défendre ses productions, analyser une matrice et relier son expérience aux compétences.",
    competency: "Certification • SWOT, productions et dossier professionnel",
    actor: "jury de certification",
    lessons: [
      ["Construire des productions probantes", "Les productions présentées avant l’épreuve doivent démontrer la veille, le plan d’actions et la gestion de la relation client. Le candidat sélectionne des situations auxquelles il a réellement contribué, anonymise les données et montre les étapes, outils, décisions, résultats et améliorations. Le support oral met en valeur les preuves plutôt que de raconter uniquement le contexte."],
      ["Passer de la SWOT à une décision", "Une SWOT distingue les facteurs internes maîtrisables des facteurs externes à anticiper. Chaque élément est précis et relié au cas. Le candidat croise ensuite les cases : utiliser une force pour saisir une opportunité, corriger une faiblesse exposée à une menace ou réduire un risque. La conclusion propose une décision commerciale, un responsable, une échéance et un indicateur."],
      ["Répondre au jury avec méthode", "Une réponse solide commence par la décision ou la compétence, apporte une preuve issue de la situation, explique le résultat puis reconnaît une limite ou une amélioration. Le candidat ne cherche pas à deviner une réponse parfaite. Il clarifie la question si nécessaire, distingue ce qu’il a fait de ce que l’équipe a réalisé et relie son expérience au référentiel RNCP39063."],
    ],
    themes: [
      ["preuve", "montrer un document, une décision ou un résultat anonymisé", "La présentation décrit une mission sans élément vérifiable.", "ajouter un outil produit, un indicateur et son utilisation", "Qu’avez-vous personnellement réalisé ?", "la preuve distingue la contribution du candidat du contexte général"],
      ["interne ou externe", "classer forces et faiblesses en interne, opportunités et menaces en externe", "Une baisse du marché est placée parmi les faiblesses.", "la reclasser comme menace et identifier la faiblesse interne associée", "Pourquoi ce classement compte-t-il ?", "les leviers internes et les facteurs externes appellent des réponses différentes"],
      ["croisement SWOT", "transformer deux constats en option stratégique", "La matrice reste une liste sans conclusion.", "croiser une force avec une opportunité puis proposer une action", "Comment votre SWOT aide-t-elle à décider ?", "elle met en relation capacités, environnement et choix commercial"],
      ["dossier professionnel", "relier chaque exemple à une compétence et à son résultat", "Le dossier énumère des tâches quotidiennes.", "sélectionner une situation complexe et expliquer la démarche", "Pourquoi ce cas démontre-t-il la compétence ?", "il montre autonomie, méthode, arbitrage et résultat"],
      ["question du jury", "répondre décision, preuve, résultat et recul", "Le candidat donne une réponse générale apprise par cœur.", "s’appuyer sur un moment précis de son expérience", "Que feriez-vous différemment ?", "le recul professionnel identifie une amélioration réaliste"],
    ],
  },
];

const toolbox = [
  ["NTC_TOOLS_PROSPECT", "Scripts de prospection", [
    ["Accroche B2B en 30 secondes", "Structurer un début d’appel centré sur le prospect.", "Fait pertinent → impact métier probable → question courte → écoute.", ["Préparer le nom, la fonction et un signal d’affaires", "Demander l’autorisation de poursuivre brièvement", "Finir par une question de contexte"]],
    ["Franchir un barrage avec respect", "Obtenir une orientation sans manipulation.", "Expliquer clairement l’objet professionnel, la valeur du sujet et la fonction recherchée.", ["Valoriser le rôle de l’interlocuteur", "Ne pas inventer de relation", "Demander le meilleur canal ou créneau"]],
    ["Relance qui apporte une valeur", "Éviter les messages je me permets de revenir.", "Rappeler le contexte, apporter un fait ou une preuve nouvelle et proposer une prochaine étape simple.", ["Une relance = une information nouvelle", "Changer de canal avec mesure", "Clôturer proprement une séquence sans réponse"]],
  ]],
  ["NTC_TOOLS_PAC", "PAC et pilotage", [
    ["Canevas de plan d’actions", "Relier chaque action à l’objectif.", "Objectif • cible • message • canal • responsable • date • moyen • KPI • risque • plan B.", ["Limiter le nombre de priorités", "Vérifier la capacité réelle", "Dater la revue"]],
    ["Funnel commercial essentiel", "Localiser l’étape qui perd de la valeur.", "Ciblés → contactés → conversations → rendez-vous qualifiés → offres → négociations → ventes → marge.", ["Calculer les taux entre étapes", "Comparer des périodes identiques", "Segmenter par cible et canal"]],
    ["Fiche action corrective", "Tester une amélioration interprétable.", "Écart → hypothèse → variable modifiée → périmètre → durée → KPI → seuil → décision.", ["Ne changer qu’une variable principale", "Conserver une référence", "Documenter aussi les tests négatifs"]],
  ]],
  ["NTC_TOOLS_DISCOVERY", "Découverte et qualification", [
    ["Carte de découverte B2B", "Comprendre le besoin et la décision.", "Situation • problème • impacts • objectifs • critères • acteurs • budget • calendrier • risques.", ["Faire quantifier les impacts", "Reformuler avant de proposer", "Repérer les informations manquantes"]],
    ["Cartographie du comité d’achat", "Adapter la valeur à chaque rôle.", "Utilisateur, prescripteur, expert technique, financeur, acheteur et décideur n’évaluent pas la même chose.", ["Identifier influence et position", "Préparer une preuve par rôle", "Ne pas contourner le contact"]],
    ["Grille de qualification rendez-vous", "Distinguer intérêt et opportunité réelle.", "Enjeu reconnu, impact, acteurs accessibles, calendrier, prochaine étape et raison d’agir.", ["Noter les faits dans le CRM", "Qualifier l’absence de besoin", "Accepter de disqualifier"]],
  ]],
  ["NTC_TOOLS_OFFER", "Proposition commerciale", [
    ["Plan de proposition professionnelle", "Faciliter la lecture et la décision.", "Contexte validé • objectifs • solution • preuves • périmètre • planning • prix • conditions • prochaine étape.", ["Faire relire les engagements", "Afficher les hypothèses", "Relier le prix à la valeur et au périmètre"]],
    ["Contrôle faisabilité-rentabilité", "Éviter de vendre une promesse impossible.", "Capacité, dépendances, coûts, marge, risques, délais, responsabilité et impact des options.", ["Valider avec les services concernés", "Chiffrer les ajouts", "Prévoir une marge de risque justifiée"]],
    ["Matrice besoin-solution-preuve", "Personnaliser sans perdre la cohérence.", "Pour chaque besoin prioritaire : composant de solution, bénéfice, preuve, condition et indicateur de résultat.", ["Reprendre les mots du client avec mesure", "Éviter les caractéristiques inutiles", "Faire valider la priorité"]],
  ]],
  ["NTC_TOOLS_NEGO", "Négociation", [
    ["Fiche de préparation négociation", "Entrer en rendez-vous avec des limites claires.", "Objectif cible • minimum • alternative • variables • coût des concessions • contreparties • pouvoirs.", ["Préparer plusieurs échanges possibles", "Ne jamais improviser la limite", "Vérifier l’autorité de décision"]],
    ["Traitement d’objection en cinq temps", "Comprendre avant de répondre.", "Accueillir • clarifier • isoler • répondre avec preuve • vérifier.", ["Ne pas contredire trop vite", "Faire préciser la comparaison", "Vérifier que le frein est levé"]],
    ["Concession conditionnelle", "Protéger la valeur de l’accord.", "Si nous faisons X, êtes-vous en mesure de vous engager sur Y ?", ["Calculer le coût", "Demander une contrepartie réelle", "Formaliser toutes les concessions"]],
  ]],
  ["NTC_TOOLS_CERT", "Certification RNCP39063", [
    ["Checklist étude de cas", "Sécuriser les livrables sous contrainte de temps.", "Commande • calculs • diagnostic • priorité • PAC • proposition • contrôle final.", ["Répartir le temps", "Nommer les hypothèses", "Relire la cohérence complète"]],
    ["Structure réponse jury", "Répondre sans réciter un cours.", "Décision → preuve précise → résultat → limite → amélioration.", ["Clarifier la question", "Distinguer je et nous", "Citer un chiffre ou un comportement observable"]],
    ["SWOT décisionnelle", "Passer de la matrice à une action.", "Classer interne/externe, hiérarchiser, croiser deux facteurs puis décider action, responsable, date et KPI.", ["Éviter les mots vagues", "Ne pas confondre faiblesse et menace", "Conclure par un arbitrage"]],
  ]],
];

const examScenarios = [
  {
    id: "NTC_EXAM_01", title: "Cybersécurité pour un réseau de cabinets comptables",
    context: "NexaSecure vend un service managé de cybersécurité aux PME. Le segment des cabinets comptables progresse, mais les offres sont peu transformées après démonstration.",
    dashboard: {"Comptes ciblés": 180, "Contacts aboutis": 72, "Rendez-vous": 30, "Propositions": 18, "Ventes": 4, "Objectif ventes": 8, "Marge moyenne": "31 %", "Cycle moyen": "76 jours"},
    constraints: ["Budget PAC maximal de 12 000 € sur trois mois", "Équipe de deux commerciaux", "Remise maximale sans validation : 5 %", "Déploiement possible sous six semaines"],
    callStartLine: "Bonjour, vous êtes bien chez NexaSecure. Je suis l’assistante de direction, quel est l’objet précis de votre appel ?",
    negotiationStartLine: "Votre solution est intéressante, mais votre concurrent annonce un prix inférieur de vingt pour cent. Pourquoi paierions-nous plus ?",
    negotiationBrief: ["Le décideur redoute l’arrêt d’activité", "L’acheteur compare surtout les prix faciaux", "Une référence client du même secteur est disponible"],
    swotPrompt: "Construis la SWOT commerciale de NexaSecure sur le segment des cabinets comptables et propose une décision pour améliorer la transformation.",
  },
  {
    id: "NTC_EXAM_02", title: "Réduction énergétique d’un site industriel",
    context: "EcoPilot propose un audit et une solution de pilotage énergétique. Les rendez-vous sont nombreux, mais le cycle de décision s’allonge et la marge baisse.",
    dashboard: {"Prospects qualifiés": 95, "Audits proposés": 40, "Audits signés": 22, "Solutions négociées": 14, "Ventes": 6, "Objectif ventes": 10, "Remise moyenne": "11 %", "Marge moyenne": "24 %"},
    constraints: ["Le client vise un retour sur investissement inférieur à 30 mois", "Validation technique obligatoire", "Remise autonome limitée à 4 %", "Installation pendant un arrêt planifié"],
    callStartLine: "Je suis le responsable maintenance. J’ai peu de temps et nous avons déjà fait plusieurs audits. Qu’avez-vous de différent ?",
    negotiationStartLine: "Votre retour sur investissement repose sur des hypothèses. Je veux une garantie et dix pour cent de remise.",
    negotiationBrief: ["Le responsable financier valide le budget", "La continuité de production est prioritaire", "Une option de mesure avant déploiement est possible"],
    swotPrompt: "Analyse les forces et faiblesses commerciales d’EcoPilot, les opportunités réglementaires et les menaces concurrentielles, puis décide d’une priorité.",
  },
  {
    id: "NTC_EXAM_03", title: "Logiciel RH pour une entreprise multisite",
    context: "Talentry commercialise un SaaS RH pour les entreprises de 200 à 1 000 salariés. Les essais sont fréquents mais l’adoption et les renouvellements restent irréguliers.",
    dashboard: {"Leads": 260, "Démonstrations": 78, "Essais": 42, "Contrats": 12, "Renouvellements attendus": 10, "Renouvellements obtenus": 6, "Utilisateurs actifs": "54 %", "Satisfaction": "7,1/10"},
    constraints: ["Migration des données incluse pour un volume limité", "Engagement standard de douze mois", "DSI et DRH participent à la décision", "Support renforcé facturable"],
    callStartLine: "Bonjour, je suis à la DRH. Nous avons déjà un outil et je ne souhaite pas organiser une démonstration inutile.",
    negotiationStartLine: "La DSI craint la migration et la DRH veut un accompagnement inclus. Votre prix dépasse notre budget.",
    negotiationBrief: ["Deux décideurs ont des critères différents", "Le faible usage de l’outil actuel est documenté", "Une phase pilote est possible"],
    swotPrompt: "Construis une SWOT de Talentry et choisis une action qui améliore à la fois la signature et le renouvellement.",
  },
  {
    id: "NTC_EXAM_04", title: "Gestion de flotte pour une société de services",
    context: "MoveoFleet propose une plateforme et des boîtiers de suivi de flotte. Le marché est concurrentiel et les prospects craignent la surveillance des salariés.",
    dashboard: {"Comptes ciblés": 140, "Contacts": 88, "Rendez-vous": 34, "Pilotes": 16, "Offres": 12, "Ventes": 5, "Objectif ventes": 9, "Durée cycle": "68 jours"},
    constraints: ["Flotte du prospect : 120 véhicules", "Déploiement progressif souhaité", "Consultation interne nécessaire", "Engagement de vingt-quatre mois privilégié"],
    callStartLine: "Je gère le parc automobile. Nous avons déjà assez de tableaux et je ne veux pas d’un outil de surveillance.",
    negotiationStartLine: "Je peux avancer uniquement avec un pilote gratuit et sans engagement. Sinon le projet s’arrête.",
    negotiationBrief: ["Le coût carburant a augmenté", "La direction veut réduire les sinistres", "Le cadre d’usage des données doit être explicite"],
    swotPrompt: "Analyse la position de MoveoFleet et formule une stratégie de pilote qui protège la valeur commerciale.",
  },
  {
    id: "NTC_EXAM_05", title: "Maintenance prédictive d’équipements frigorifiques",
    context: "FroidPrevent vend des capteurs et un contrat de maintenance aux réseaux alimentaires. Les prospects comprennent la technique mais hésitent sur l’investissement initial.",
    dashboard: {"Sites prospectés": 110, "Diagnostics": 38, "Propositions": 25, "Négociations": 17, "Ventes": 7, "Objectif ventes": 11, "Panier moyen": "28 000 €", "Pertes liées au prix": "41 %"},
    constraints: ["Installation de nuit possible", "Contrat de maintenance de trois ans", "Coût d’un incident estimé par le prospect à 9 000 €", "Financement échelonné disponible"],
    callStartLine: "Je suis le directeur technique. Vos capteurs sont sûrement utiles, mais notre maintenance actuelle fonctionne.",
    negotiationStartLine: "Vingt-huit mille euros est trop élevé. Je veux retirer la maintenance et acheter uniquement les capteurs.",
    negotiationBrief: ["Le client a subi deux incidents récents", "La maintenance finance une partie de la qualité de service", "Un paiement échelonné est possible"],
    swotPrompt: "Réalise la SWOT de FroidPrevent et propose un repositionnement de la valeur face à l’objection d’investissement.",
  },
  {
    id: "NTC_EXAM_06", title: "Emballages réemployables pour la restauration collective",
    context: "ReUsePack propose des contenants, une logistique de collecte et un suivi numérique. Les appels d’offres augmentent mais les coûts logistiques fragilisent les marges.",
    dashboard: {"Appels d’offres détectés": 32, "Réponses": 21, "Présélections": 13, "Négociations": 9, "Contrats": 4, "Objectif contrats": 7, "Marge moyenne": "18 %", "Coût logistique": "27 % du CA"},
    constraints: ["Trois zones de livraison possibles", "Volume minimal pour la collecte", "Traçabilité incluse", "Engagement environnemental mesurable demandé"],
    callStartLine: "Je pilote les achats. Nous étudions plusieurs solutions, mais la logistique de retour nous inquiète.",
    negotiationStartLine: "Votre concurrent inclut toutes les collectes. Je veux le même service avec votre prix actuel.",
    negotiationBrief: ["Le volume varie selon les sites", "Le client valorise les preuves d’impact", "Une fréquence de collecte différente change fortement la marge"],
    swotPrompt: "Construis la SWOT de ReUsePack et propose un modèle commercial qui concilie impact client et rentabilité.",
  },
];

class Writer {
  constructor() {
    this.batch = db.batch();
    this.count = 0;
    this.total = 0;
  }

  async set(ref, data, options = {merge: true}) {
    this.total++;
    if (!APPLY) return;
    this.batch.set(ref, data, options);
    this.count++;
    if (this.count >= 400) await this.flush();
  }

  async flush() {
    if (!APPLY || this.count === 0) return;
    await this.batch.commit();
    this.batch = db.batch();
    this.count = 0;
  }
}

function arranged(correct, wrong, position) {
  const options = [...wrong];
  const index = position % 4;
  options.splice(index, 0, correct);
  return {options, correctAnswer: index};
}

function questionsFor(module) {
  const sets = {level_easy: [], level_medium: [], level_expert: []};
  module.themes.forEach((theme, index) => {
    const [name, principle, situation, action, jury, reason] = theme;
    const easy = arranged(principle, [
      "Appliquer une réponse identique à tous les contextes",
      "Décider uniquement à l’intuition",
      "Promettre un résultat avant d’avoir vérifié les données",
    ], index);
    sets.level_easy.push({
      question: `Concernant « ${name} », quelle pratique est la plus professionnelle ?`,
      ...easy,
      explanation: `${principle}. Cette pratique relie la méthode à une décision commerciale vérifiable.`,
    });

    const medium = arranged(action, [
      "Maintenir l’action actuelle sans analyser l’écart",
      "Donner immédiatement une solution standard",
      "Transférer la décision à un tiers sans préparer les faits",
    ], index + 1);
    sets.level_medium.push({
      question: `Cas professionnel : ${situation} Quelle action choisissez-vous ?`,
      ...medium,
      explanation: `${action}. La réponse part des faits, protège la valeur et prépare une suite mesurable.`,
    });

    const expert = arranged(reason, [
      "Parce que cette méthode est toujours utilisée dans l’entreprise",
      "Parce que cela permet d’éviter toute objection",
      "Parce que le jury attend une réponse longue",
    ], index + 2);
    sets.level_expert.push({
      question: `Question du jury : « ${jury} » Quelle justification est la plus solide ?`,
      ...expert,
      explanation: `${reason}. La justification associe une décision, une preuve et son impact.`,
    });
  });
  return sets;
}

function lessonEnrichment(module, lessonIndex) {
  const primary = module.themes[(lessonIndex * 2) % module.themes.length];
  const secondary = module.themes[(lessonIndex * 2 + 1) % module.themes.length];
  const [name, principle, situation, action, juryQuestion, reason] = primary;
  const [secondaryName, secondaryPrinciple, secondarySituation, secondaryAction] = secondary;

  return {
    learningObjectives: [
      `Expliquer le principe professionnel lié à ${name} avec des mots simples.`,
      `Choisir une action adaptée face à une situation réelle avec ${module.actor}.`,
      `Justifier la décision avec une preuve, un indicateur et une prochaine étape.`,
    ],
    keyPoints: [
      principle,
      secondaryPrinciple,
      `Toujours relier la méthode à un fait vérifiable et à une décision commerciale.`,
      `Tracer l'action, le responsable, l'échéance et le résultat attendu dans l'outil de suivi.`,
    ],
    fieldExample: {
      context: `Vous intervenez comme NTC face à un ${module.actor}. ${situation}`,
      weakApproach: `Répondre immédiatement avec un argument standard, sans clarifier les faits ni vérifier le véritable enjeu.`,
      expertApproach: `${action}. Puis reformuler l'accord obtenu et fixer une prochaine étape datée.`,
      debrief: `${reason}. La réponse reste crédible parce qu'elle distingue les faits, l'hypothèse et l'engagement réellement autorisé.`,
    },
    challenge: {
      prompt: `${secondarySituation} Préparez une réponse en quatre temps : constat, question, proposition et indicateur de réussite.`,
      modelAnswer: `Je pars du constat communiqué sans l'interpréter trop vite. Je pose une question pour préciser ${secondaryName}. Je propose ensuite de ${secondaryAction}. Enfin, je conviens avec l'interlocuteur d'un indicateur et d'une date de vérification.`,
    },
    jury: {
      question: juryQuestion,
      modelAnswer: `Ma décision est de ${action}. Je m'appuie sur les faits du cas et sur le principe suivant : ${principle}. Le résultat attendu est mesurable lors de la prochaine étape. La limite est que l'hypothèse doit encore être confirmée avec le client ou le service compétent.`,
    },
    checklist: [
      `Je sais définir ${name} sans réciter le cours.`,
      `Je sais reconnaître une pratique insuffisante et expliquer son risque.`,
      `Je sais appliquer la méthode à un autre secteur commercial.`,
      `Je sais répondre au jury avec décision, preuve, résultat et limite.`,
    ],
    memoryTip: `Faits → question → décision → preuve → prochaine étape. Cette chaîne évite les réponses vagues et protège la crédibilité commerciale.`,
    audioEnabled: true,
    audioMode: "device_tts",
  };
}

function simulationFor(module, theme, index) {
  const [name, principle, situation, action, jury, reason] = theme;
  const tones = ["pressé et factuel", "sceptique mais ouvert", "exigeant et précis"];
  return {
    order: index + 1,
    track: TRACK,
    rncpReference: RNCP,
    diplomaTitle: DIPLOMA,
    title: `Mise en situation • ${name}`,
    actor: module.actor,
    startLine: situation,
    persona: {
      role: module.actor,
      tone: tones[index % tones.length],
      goal: "obtenir des réponses concrètes avant d’accepter la prochaine étape",
      reactions: {
        si_ecoute: "donne progressivement des informations utiles",
        si_promesse: "demande une preuve et les conditions exactes",
      },
    },
    briefing: {
      title: `Mise en situation • ${name}`,
      duration: "10–12 min",
      objectives: [principle, action, reason],
      plan: ["Cadrer l’échange", "Questionner les faits", "Reformuler", "Proposer une prochaine étape"],
      starterPhrases: ["Pour bien comprendre, pouvez-vous préciser…", "Si je reformule votre priorité…", "Je vous propose de vérifier ce point puis de…"],
      pitfalls: ["Réciter un argumentaire", "Promettre sans validation", "Conclure sans prochaine étape"],
    },
    objectives: [principle, action, reason],
    plan: ["Cadrer", "Découvrir", "Argumenter avec une preuve", "Conclure"],
    pitfalls: ["Parler trop tôt de la solution", "Ignorer une objection", "Inventer une information"],
    notExpected: ["Manipuler l’interlocuteur", "Accorder une condition non autorisée", "Masquer un risque connu"],
    rubric: {
      cadrage: "Objectif et déroulé clairs",
      questionnement: "Questions pertinentes et progressives",
      valeur: "Argument relié au besoin avec preuve",
      conclusion: "Accord ou prochaine étape explicite",
    },
    juryQuestion: jury,
    curriculumVersion: 4,
    contentStatus: "ntc_expert_2026",
  };
}

function examScenarioData(scenario, order) {
  return {
    ...scenario,
    order: 100 + order,
    examScenario: true,
    track: TRACK,
    rncpReference: RNCP,
    diplomaTitle: DIPLOMA,
    actor: "décideur client",
    persona: {
      role: "décideur B2B et membre du comité d’achat",
      tone: order % 2 === 0 ? "direct, exigeant et orienté rentabilité" : "prudent, technique et attentif aux risques",
      goal: "vérifier la valeur, la faisabilité et les conditions avant de s’engager",
      reactions: {
        si_ecoute: "révèle les critères et les contraintes progressivement",
        si_remise: "demande un effort supplémentaire",
        si_preuve: "questionne la méthode et la comparabilité",
      },
    },
    callObjectives: ["Identifier le bon interlocuteur", "Créer un intérêt contextualisé", "Qualifier brièvement", "Obtenir un rendez-vous précis"],
    negotiationObjectives: ["Actualiser la découverte", "Présenter une solution rentable", "Traiter les objections", "Négocier avec contreparties", "Conclure et tracer"],
    objectives: ["Analyser les données", "Construire un PAC", "Concevoir la proposition", "Prospecter", "Négocier", "Analyser sa pratique"],
    plan: ["Diagnostic", "Priorités", "Proposition", "Découverte", "Négociation", "Conclusion"],
    pitfalls: ["Inventer une donnée", "Baisser le prix sans contrepartie", "Ignorer le circuit de décision", "Promettre une faisabilité non validée"],
    notExpected: ["Donner les réponses au candidat", "Accepter immédiatement l’offre", "Sortir du contexte fourni"],
    rubric: {
      analyse: "Calculs, écarts, causes et priorités cohérents",
      prospection: "Accroche, qualification et rendez-vous",
      proposition: "Besoin, solution, preuve, faisabilité et rentabilité",
      negociation: "Valeur, objections, concessions et contreparties",
      conclusion: "Engagements, risques et prochaine étape",
    },
    curriculumVersion: 4,
    contentStatus: "ntc_exam_interactive_2026",
  };
}

function validateContent() {
  const chapterIds = new Set(chapters.map((chapter) => chapter.id));
  const moduleIds = new Set();
  let lessonCount = 0;
  let questionCount = 0;
  let simulationCount = 0;
  for (const module of modules) {
    if (!chapterIds.has(module.chapter)) {
      throw new Error(`Chapitre inconnu pour ${module.id}: ${module.chapter}`);
    }
    if (moduleIds.has(module.id)) throw new Error(`Module dupliqué: ${module.id}`);
    moduleIds.add(module.id);
    if (module.lessons.length !== 3) {
      throw new Error(`${module.id}: exactement 3 leçons sont requises.`);
    }
    for (const [lessonIndex, [title, content]] of module.lessons.entries()) {
      if (!title || content.length < 300) {
        throw new Error(`${module.id}: leçon trop courte ou sans titre.`);
      }
      const enriched = lessonEnrichment(module, lessonIndex);
      if (enriched.learningObjectives.length < 3 ||
          enriched.keyPoints.length < 4 ||
          enriched.checklist.length < 4 ||
          !enriched.fieldExample.context ||
          !enriched.fieldExample.expertApproach ||
          !enriched.challenge.prompt ||
          !enriched.challenge.modelAnswer ||
          !enriched.jury.question ||
          !enriched.jury.modelAnswer ||
          enriched.audioEnabled !== true) {
        throw new Error(`${module.id}: enrichissement interactif incomplet pour ${title}.`);
      }
    }
    if (module.themes.length < 5) {
      throw new Error(`${module.id}: au moins 5 thèmes évalués sont requis.`);
    }
    if (module.themes.some((theme) => theme.length !== 6 || theme.some((part) => !part))) {
      throw new Error(`${module.id}: thème incomplet.`);
    }
    const generated = questionsFor(module);
    for (const questions of Object.values(generated)) {
      for (const question of questions) {
        if (question.options.length !== 4 || question.correctAnswer < 0 || question.correctAnswer > 3) {
          throw new Error(`${module.id}: question générée invalide.`);
        }
      }
    }
    lessonCount += module.lessons.length;
    questionCount += module.themes.length * 3;
    simulationCount += Math.min(3, module.themes.length);
  }
  const examIds = new Set(examScenarios.map((scenario) => scenario.id));
  if (examIds.size !== examScenarios.length) throw new Error("Sujet d'examen dupliqué.");
  if (examScenarios.length < 6) throw new Error("Au moins 6 sujets d'examen sont requis.");
  for (const scenario of examScenarios) {
    if (!scenario.title || !scenario.context || !scenario.callStartLine ||
        !scenario.negotiationStartLine || Object.keys(scenario.dashboard || {}).length < 6) {
      throw new Error(`Sujet d'examen incomplet: ${scenario.id}`);
    }
  }
  console.log(
      `Corpus NTC validé: ${modules.length} modules, ${lessonCount} leçons, ` +
      `${questionCount} questions, ${simulationCount} simulations et ${examScenarios.length} examens.`,
  );
}

async function main() {
  validateContent();
  const writer = new Writer();

  await writer.set(db.collection("tracks").doc(TRACK), {
    title: "Négociateur technico-commercial",
    shortTitle: "NTC • Commercial terrain",
    subtitle: "Préparation complète au titre professionnel de niveau 5 — RNCP39063",
    badge: "🚀",
    color1: 0xFF1D4ED8,
    color2: 0xFF059669,
    order: 3,
    published: true,
    rncpReference: RNCP,
    level: 5,
    validUntil: "2029-06-10",
    sourceTitle: "France Compétences — RNCP39063",
    sourceUrl: RNCP_URL,
    assistant: {
      title: "Coach Commercial NTC",
      subtitle: "Réponses instantanées et gratuites, limitées aux cours et fiches RNCP39063.",
      suggestions: [
        "Comment construire un plan d’actions commerciales ?",
        "Comment préparer un appel de prospection B2B ?",
        "Comment analyser un tableau de bord commercial ?",
        "Comment rédiger une proposition technique et commerciale ?",
        "Comment traiter une objection sans baisser immédiatement le prix ?",
        "Comment préparer la négociation et les questions du jury NTC ?",
      ],
    },
    exam: {
      enabled: true,
      kind: "ntc_rncp39063",
      chapterId: "NTC_CERT",
      moduleId: "NTC_CERT_E2",
      officialMinutes: 510,
      premium: true,
    },
    curriculumVersion: 4,
    updatedAt: FieldValue.serverTimestamp(),
  });

  for (const chapter of chapters) {
    const chapterModules = modules.filter((module) => module.chapter === chapter.id);
    const chapterRef = db.collection("chapters").doc(chapter.id);
    await writer.set(chapterRef, {
      track: TRACK,
      order: chapter.order,
      title: chapter.title,
      description: chapter.description,
      numberOfModules: chapterModules.length,
      rncpReference: RNCP,
      sourceTitle: "France Compétences — RNCP39063",
      sourceUrl: RNCP_URL,
      curriculumVersion: 4,
      contentStatus: "ntc_expert_2026",
    });

    for (const module of chapterModules) {
      const moduleRef = chapterRef.collection("modules").doc(module.id);
      await writer.set(moduleRef, {
        track: TRACK,
        order: module.order,
        title: module.title,
        description: module.description,
        numberOfLessons: module.lessons.length,
        numberOfLevels: 3,
        rncpReference: RNCP,
        rncpCompetency: module.competency,
        sourceTitle: "Référentiel RNCP39063",
        sourceUrl: RNCP_URL,
        curriculumVersion: 4,
        contentStatus: "ntc_expert_2026",
      });

      for (let index = 0; index < module.lessons.length; index++) {
        const [title, content] = module.lessons[index];
        const enrichment = lessonEnrichment(module, index);
        await writer.set(moduleRef.collection("lessons").doc(`L${index + 1}`), {
          track: TRACK,
          order: index + 1,
          title,
          content,
          durationMinutes: 14,
          rncpReference: RNCP,
          rncpCompetency: module.competency,
          sourceTitle: "Référentiel RNCP39063",
          sourceUrl: RNCP_URL,
          curriculumVersion: 4,
          contentStatus: "ntc_interactive_audio_2026",
          ...enrichment,
        });
      }

      const sets = questionsFor(module);
      for (const [levelId, questions] of Object.entries(sets)) {
        const levelRef = moduleRef.collection("levels").doc(levelId);
        const levelOrder = levelId === "level_easy" ? 1 : levelId === "level_medium" ? 2 : 3;
        await writer.set(levelRef, {
          track: TRACK,
          order: levelOrder,
          difficulty: levelId.replace("level_", ""),
          passingScore: 80,
          questionCount: questions.length,
        });
        for (let index = 0; index < questions.length; index++) {
          await writer.set(levelRef.collection("questions").doc(`Q${String(index + 1).padStart(2, "0")}`), {
            ...questions[index],
            track: TRACK,
            rncpReference: RNCP,
            rncpCompetency: module.competency,
            sourceTitle: "Référentiel RNCP39063",
            sourceUrl: RNCP_URL,
            curriculumVersion: 4,
            contentStatus: "ntc_expert_2026",
          });
        }
      }

      for (let index = 0; index < Math.min(3, module.themes.length); index++) {
        await writer.set(
            moduleRef.collection("simulations").doc(`SIM_${index + 1}`),
            simulationFor(module, module.themes[index], index),
        );
      }
    }
  }

  for (let categoryIndex = 0; categoryIndex < toolbox.length; categoryIndex++) {
    const [categoryId, title, items] = toolbox[categoryIndex];
    const categoryRef = db.collection("toolbox_categories").doc(categoryId);
    await writer.set(categoryRef, {
      track: TRACK,
      order: categoryIndex + 1,
      title,
      rncpReference: RNCP,
      curriculumVersion: 4,
    });
    for (let itemIndex = 0; itemIndex < items.length; itemIndex++) {
      const [itemTitle, summary, content, reflexes] = items[itemIndex];
      await writer.set(categoryRef.collection("items").doc(`ITEM_${itemIndex + 1}`), {
        track: TRACK,
        order: itemIndex + 1,
        title: itemTitle,
        summary,
        content,
        reflexes,
        vigilances: ["Adapter au contexte réel", "Vérifier les données", "Tracer la prochaine étape"],
        rncpReference: RNCP,
        sourceTitle: "Référentiel RNCP39063",
        sourceUrl: RNCP_URL,
        curriculumVersion: 4,
        contentStatus: "ntc_expert_2026",
      });
    }
  }

  const examRef = db.collection("chapters").doc("NTC_CERT")
      .collection("modules").doc("NTC_CERT_E2").collection("simulations");
  for (let index = 0; index < examScenarios.length; index++) {
    const scenario = examScenarios[index];
    await writer.set(examRef.doc(scenario.id), examScenarioData(scenario, index + 1));
  }

  await writer.set(db.collection("app_config").doc("exam_ntc_v3"), {
    track: TRACK,
    rncpReference: RNCP,
    officialExamMinutes: 510,
    writtenMinutes: 240,
    callMinutes: 15,
    negotiationMinutes: 60,
    sourceUrl: RNCP_URL,
    curriculumVersion: 4,
    updatedAt: FieldValue.serverTimestamp(),
  });

  await writer.flush();
  console.log(`${APPLY ? "Migration NTC appliquée" : "Simulation NTC uniquement"}: ${writer.total} écritures prévues.`);
  if (!APPLY) console.log("Relancer avec npm run migrate:ntc:apply après vérification.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
