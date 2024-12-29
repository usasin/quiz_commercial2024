import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lottie/lottie.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/gpt_service.dart';
import 'compte_rendu_screen.dart';

enum SalesStep {
  Introduction,
  Motivation,
  CurrentSituation,
  Pain,
  DesiredSituation,
  OurSolution,
  Objections,
  Validation,
  Recap,
  Closing,
}

class Simulation extends StatefulWidget {
  final String chapterId;
  Simulation({required this.chapterId});

  @override
  _SimulationState createState() => _SimulationState();
}

class _SimulationState extends State<Simulation> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isRecruiterSpeaking = false;
  final GptService _gptService = GptService(); // Réinclusion du service GPT
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  String? salesScript;
  bool _isListening = false;
// Ajout pour gérer l'état de validation
  Duration maxSilence = Duration(seconds: 30); // Temps maximum de silence autorisé
  String? userProfilePhotoUrl;
  List<int> loadingMessages = []; // Stocke les index des messages en cours de chargement
  final ScrollController _scrollController = ScrollController();
  bool isSpeaking = false; // Variable pour gérer l'état de la parole

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      String currentLanguage = context.locale.languageCode;
      _configureTts(currentLanguage);
      _speakInitialRecruiterMessage();
    });
    _initializeSalesScript();
    flutterTts.setStartHandler(() {
      setState(() {
        isRecruiterSpeaking = true;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        isRecruiterSpeaking = false;
      });
    });

    // Récupérer la photo de profil de l'utilisateur
    _loadUserProfile();
  }


  Future<void> _loadUserProfile() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.photoURL != null) {
      setState(() {
        userProfilePhotoUrl = currentUser.photoURL;
      });
    }
  }

  Future<void> _initializeSalesScript() async {
    String scriptId = widget.chapterId;
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('scripts').doc(scriptId).get();

    if (doc.exists && doc.data() != null) {
      setState(() {
        salesScript = doc['sales_script'] ?? '';  // Vérifier si le script existe
      });
    } else {
      print("Le script pour ce chapitre n'existe pas.");
    }
  }

  String getSalesTechnique(String chapterId) {
    switch (chapterId) {
      case 'chapter1':
        return "Vente Directe (Porte-à-Porte, One-Shot)";
      case 'chapter2':
        return "Setting & Closing à Vente Distance";
      case 'chapter3':
        return "La Vente en GMS";
      case 'chapter4':
        return "Commercial en Immobilier";
      case 'chapter5':
        return "La Vente Consultative";
      case 'chapter6':
        return "Responsable Commercial / Manager Commercial";
      case 'chapter7':
        return "Commerciaux High Ticket (Ventes à Haute Valeur)";
      case 'chapter8':
        return "Marketing Digital et Community Management";
      default:
        return "technique de vente non spécifiée";
    }
  }

  Future<void> _speakInitialRecruiterMessage() async {
    String salesTechnique = getSalesTechnique(widget.chapterId);
    String message = "Bienvenue dans le Mode Libre de la simulation de $salesTechnique. "
        "Dans ce mode, l'IA ne vous guidera pas, mais vous passerez à travers chaque étape du processus de vente. "
        "À la fin, un compte rendu sera généré. Appuyez sur 'Parler' ou tapez vos réponses pour interagir.".tr();
    await flutterTts.speak(message);
  }

  void _configureTts(String languageCode) async {
    await flutterTts.setLanguage(languageCode); // Définit la langue
    await flutterTts.setPitch(1.0); // Définit le ton
    await flutterTts.setSpeechRate(0.6); // Définit la vitesse de parole
    await flutterTts.setVolume(1.0); // Définit le volume au maximum

    // (Optionnel) Configure une voix spécifique
    List<dynamic>? voices = await flutterTts.getVoices;
    dynamic voice = voices?.firstWhere(
          (v) => v['locale'] == languageCode,
      orElse: () => null,
    );

    if (voice != null) {
      await flutterTts.setVoice(voice); // Définit une voix spécifique si disponible
    } else {
      print("Aucune voix spécifique trouvée pour la langue $languageCode");
    }
  }


  final List<Map<String, dynamic>> _messages = [
    {
      "role": "system",
      'content': "Bienvenue dans le Mode Libre de la simulation. Vous suivrez toutes les étapes de vente, de l'introduction à la conclusion. À la fin, un rapport sera généré.".tr()
    },
  ];

  void _sendMessage(String content) async {
    setState(() {
      _messages.add({
        'role': 'user',
        'content': content,
      });
    });

    try {
      String contextPrompt = """
    Vous êtes un gérant dans une simulation de vente. 
    - **Répondez de manière simple et directe** aux questions du commercial.
    - Pour les **questions fermées** ou très spécifiques (par exemple, 'Quel est votre prénom ?'), répondez uniquement avec l'information demandée sans poser de questions supplémentaires.
    - Pour les **questions ouvertes** ou lorsque le commercial invite à une discussion (par exemple, 'Quelles sont vos priorités ?'), donnez une réponse plus détaillée et posez une question en retour si cela est pertinent pour approfondir la conversation.
    - Gardez un ton amical et professionnel.
    """;

      final combinedScript = "$contextPrompt\n$salesScript";

      final response = await _gptService.generateTextBasedOnSalesScript(_messages, combinedScript);
      _addRecruiterQuestion(response);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la génération de la réponse de l'IA.")),
      );
    }
  }

  Future<String> generateTrainingReport() async {
    try {
      // Construisez un prompt basé sur les interactions utilisateur et assistant
      String trainingPrompt = """
    Vous êtes un formateur en vente. Analysez les interactions suivantes entre le commercial et le gérant :
    - Identifiez les **points positifs**.
    - Soulignez les **axes d'amélioration**.
    - Fournissez des **recommandations claires** pour progresser.

    Interactions :
    ${_messages.map((m) => "${m['role']}: ${m['content']}").join("\n")}
    """;

      // Appel API pour générer le rapport
      final report = await _gptService.generateText([
        {'role': 'system', 'content': 'Agissez en tant que formateur.'},
        {'role': 'user', 'content': trainingPrompt},
      ]);

      return report;
    } catch (e) {
      print("Erreur lors de la génération du compte rendu : $e");
      return "Erreur lors de la génération du compte rendu.";
    }
  }




  void _addRecruiterQuestion(String question) async {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': question, // Affiche immédiatement le texte
      });
    });

    _scrollToBottom(); // Scrollez automatiquement vers le bas

    // Parle le message et garde Lottie actif
    await _speak(question);

    _scrollToBottom(); // Scrollez à nouveau après la fin de la parole
  }


  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }



  Future<void> _startListening() async {
    bool available = await speech.initialize(
      onStatus: (status) {
        if (status == 'listening') {
          setState(() {
            _isListening = true;
          });
        }
      },
      onError: (error) => print('onError: $error'),
    );

    if (available) {
      speech.listen(
        listenFor: Duration(minutes: 1), // Délai d'écoute maximal
        pauseFor: Duration(minutes: 1),  // Délai d'inactivité avant arrêt augmenté au maximum
        onResult: (result) {
          _controller.text = result.recognizedWords;
        },
      );
    }
  }


  void _stopListening() {
    speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    flutterTts.stop();
    speech.stop();
    super.dispose();
  }




  Future<void> _speak(String text) async {
    try {
      // Active l'animation Lottie
      setState(() {
        isSpeaking = true;
      });

      // Gestionnaires pour activer/désactiver Lottie
      flutterTts.setStartHandler(() {
        setState(() {
          isSpeaking = true;
        });
      });

      flutterTts.setCompletionHandler(() {
        setState(() {
          isSpeaking = false; // Désactive l'animation à la fin de la parole
        });
      });

      flutterTts.setErrorHandler((msg) {
        setState(() {
          isSpeaking = false; // Désactive également en cas d'erreur
        });
      });

      await flutterTts.speak(text); // Commence la parole
    } catch (e) {
      print("Erreur lors de la lecture du texte : $e");
      setState(() {
        isSpeaking = false; // Assurez-vous de désactiver en cas d'erreur
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              // En-tête
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20), // Espacement horizontal pour le conteneur
                color: Colors.white70, // Fond blanc cassé pour le conteneur
                child: Column(
                  children: [
                    SizedBox(height: 50), // Espace pour descendre le bouton
                    ElevatedButton.icon(
                      icon: Icon(Icons.ads_click, color: Colors.orangeAccent, size: 24), // Icône du bouton
                      label: Text(
                        'Clic Terminer'.tr(), // Texte du bouton
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.blue.shade800, // Couleur du texte
                          fontWeight: FontWeight.bold, // Mettre en gras pour renforcer le style
                        ),
                      ),
                      onPressed: () {
                        _showExitConfirmationDialog(); // Appelle la méthode pour afficher le dialogue
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade50, // Couleur de fond du bouton
                        shadowColor: Colors.brown.shade200, // Couleur de l'ombre pour l'effet 3D
                        elevation: 10, // Élévation pour créer de la profondeur
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15), // Coins arrondis pour un style moderne
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16), // Espacement interne
                      ),
                    ),
                  ],
                ),
              ),




              // Corps principal
              Expanded(
                child: Stack(
                  children: <Widget>[
                    // Fond d'écran
                    Opacity(
                      opacity: 0.9,
                      child: Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/background_concours.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    // Liste des messages
                    Column(
                      children: <Widget>[
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController, // Ajout du contrôleur
                            itemCount: _messages.length,
                            itemBuilder: (BuildContext context, int index) {
                              final message = _messages[index];
                              final isUserMessage = message['role'] == 'user';
                              final isAssistantMessage = message['role'] == 'assistant';

                              return Column(
                                crossAxisAlignment: isUserMessage
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (isAssistantMessage) ...[
                                    // Affiche le texte immédiatement
                                    Container(
                                      color: Colors.green[100],
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4.0, horizontal: 8.0),
                                      padding: const EdgeInsets.all(8.0),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage:
                                          AssetImage('assets/images/system.png'),
                                          backgroundColor: Colors.grey,
                                        ),
                                        title: Text(
                                          message['content'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                        subtitle: Text('Gérant'.tr()),
                                      ),
                                    ),
                                  ],
                                  if (isUserMessage)
                                    Container(
                                      color: Colors.blue[100],
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4.0, horizontal: 8.0),
                                      padding: const EdgeInsets.all(8.0),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: userProfilePhotoUrl != null
                                              ? NetworkImage(userProfilePhotoUrl!)
                                              : AssetImage(
                                              'assets/images/default_user.png'),
                                          backgroundColor: Colors.grey,
                                        ),
                                        title: Text(
                                          message['content'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text('Commercial'.tr()),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Champ de texte
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'Ou tapez votre message ici...'.tr(),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            minLines: 1,
                            maxLines: 5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Boutons
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.mic,
                          color: Colors.white, // L'icône reste blanche
                          size: 30,
                        ),
                        label: Text(
                          _isListening ? 'Stop'.tr() : 'Parler'.tr(), // Change le texte en fonction de l'état
                          style: TextStyle(
                            color: Colors.white, // Le texte reste blanc
                            fontSize: 20,
                          ),
                        ),
                        onPressed: () {
                          if (_isListening) {
                            _stopListening(); // Arrête l'écoute
                          } else {
                            _startListening(); // Démarre l'écoute
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: _isListening
                              ? Colors.red // Rouge pendant l'écoute
                              : Colors.green, // Vert par défaut
                        ),
                      ),
                    ),


                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.send, color: Colors.white, size: 30),
                        label: Text(
                          'Valider'.tr(),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          final value = _controller.text.trim();
                          if (value.isNotEmpty) {
                            _sendMessage(value);
                            _controller.clear();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Animation Lottie en superposition au centre
          if (isSpeaking)
            Center(
              child: Lottie.asset(
                'assets/parler.json',
                width: MediaQuery.of(context).size.width * 0.7, // 60% de la largeur
                height: MediaQuery.of(context).size.width * 0.6, // Carré
                repeat: true,
              ),
            ),
        ],
      ),
    );
  }


  void endOfSimulation() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Appel à generateTrainingReport
      String report = await generateTrainingReport();

      // Sauvegarde dans Firestore
      await _saveInterviewReportToFirestore(report);

      // Fermer le dialogue de chargement
      Navigator.pop(context);

      // Naviguer vers l'écran de compte rendu
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompteRenduScreen(
            chapterId: widget.chapterId,

          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      print("Erreur dans endOfSimulation : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Une erreur est survenue. Veuillez réessayer.")),
      );
    }
  }




  String generateInterviewReport() {
    StringBuffer report = StringBuffer();

    // Introduction
    report.writeln("# Compte Rendu de la Simulation de Vente");
    report.writeln("Voici une analyse détaillée de votre simulation :\n");

    // Points positifs
    report.writeln("## Points Positifs");
    bool hasPositive = false;
    for (var message in _messages) {
      if (message['role'] == 'assistant' &&
          message['content'].toLowerCase().contains("bien")) {
        report.writeln("- ${message['content']}");
        hasPositive = true;
      }
    }
    if (!hasPositive) {
      report.writeln("- Aucun point positif explicite trouvé, mais l’effort est visible !");
    }

    // Axes d’amélioration
    report.writeln("\n## Axes d’Amélioration");
    bool hasImprovement = false;
    for (var message in _messages) {
      if (message['role'] == 'assistant' &&
          message['content'].toLowerCase().contains("problème")) {
        report.writeln("- ${message['content']}");
        hasImprovement = true;
      }
    }
    if (!hasImprovement) {
      report.writeln("- Aucun problème détecté, mais vous pouvez toujours affiner vos réponses.");
    }

    // Recommandations
    report.writeln("\n## Recommandations de votre coach");
    report.writeln("- Donnez des exemples plus spécifiques et concrets.");
    report.writeln("- Posez des questions ouvertes pour explorer davantage les besoins du client.");
    report.writeln("- Soyez précis et concis dans vos réponses.");

    // Conclusion
    report.writeln("\n## Conclusion");
    report.writeln("Votre simulation est prometteuse. Continuez à travailler sur les axes identifiés pour exceller dans vos prochaines interactions.");

    return report.toString();
  }


  Future<void> _saveInterviewReportToFirestore(String report) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && report.isNotEmpty) {
      try {
        // Sauvegarder le rapport dans Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('chapters')
            .doc(widget.chapterId)
            .set({
          'interviewReport': report, // Ajouter le compte rendu généré
          'gptMessages': _messages,  // Ajouter les messages de la conversation
          'timestamp': FieldValue.serverTimestamp(), // Ajouter une date pour le suivi
        }, SetOptions(merge: true));

        print("Rapport sauvegardé avec succès !");
      } catch (e) {
        print("Erreur lors de la sauvegarde du rapport : $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la sauvegarde du rapport.")),
        );
      }
    } else {
      print("Utilisateur non connecté ou rapport vide.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible de sauvegarder : utilisateur non connecté ou rapport vide.")),
      );
    }
  }



  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Terminer la simulation ?"),
        content: Text(
          "Voulez-vous terminer la simulation et générer un compte rendu ?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fermer le dialogue
            },
            child: Text("Annuler"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Fermer le dialogue
              await _generateAndSaveReport(); // Générer le rapport
            },
            child: Text("Confirmer"),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSaveReport() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Générer le compte rendu
      final reportPrompt = """
    Vous êtes un formateur en vente. Voici les interactions enregistrées :
    ${_messages.map((m) => "${m['role']}: ${m['content']}").join("\n")}

    Générer un compte rendu clair avec :
    - Les points positifs
    - Les axes d'amélioration
    - Des recommandations pratiques.
    """;

      final report = await _gptService.generateText([
        {'role': 'system', 'content': 'Générez un compte rendu structuré et détaillé basé sur ces interactions.'},
        {'role': 'user', 'content': reportPrompt},
      ]);

      // Sauvegarder le rapport dans Firestore
      await _saveInterviewReportToFirestore(report);

      Navigator.pop(context);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CompteRenduScreen(
            chapterId: widget.chapterId,

          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la génération du compte rendu.")),
      );
    }
  }





}