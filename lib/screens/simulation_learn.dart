
import 'dart:io'; // Import ajouté pour la détection de plateforme
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lottie/lottie.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/gpt_service.dart';
import 'compte_rendu_screen.dart';

class SimulationLearn extends StatefulWidget {
  final String chapterId;
  SimulationLearn({required this.chapterId});

  @override
  _SimulationLearnState createState() => _SimulationLearnState();
}

class _SimulationLearnState extends State<SimulationLearn> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GptService _gptService = GptService();
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  final ScrollController _scrollController = ScrollController();

  bool isTrainerSpeaking = false;
  bool isSpeaking = false;
  bool _isListening = false;
  String? userProfilePhotoUrl;
  String? salesScript;
  Duration maxSilence = Duration(seconds: 30);

  final List<Map<String, dynamic>> _messages = [
    {
      "role": "system",
      'content': "Bienvenue dans le mode d'apprentissage de vente. Vous serez guidé et corrigé après chaque étape."
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      String currentLanguage = context.locale.languageCode;
      _configureTts(currentLanguage);
      _speakInitialTrainerMessage();
    });
    _initializeSalesScript();
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
        salesScript = doc['sales_script'] ?? '';
      });
    } else {
      print("Le script pour ce chapitre n'existe pas.");
    }
  }

  Future<void> _speakInitialTrainerMessage() async {
    String message = "Bienvenue dans le mode d'apprentissage. Ici, je vais vous guider étape par étape dans le processus de vente. "
        "Je vous donnerai des retours après chaque interaction. Appuyez sur 'Parler' pour commencer.";
    await flutterTts.speak(message);

    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': message,
      });
    });
  }

  // Configuration de Flutter TTS avec les réglages pour forcer la sortie sur le haut-parleur
  void _configureTts(String languageCode) async {
    // Définition de la langue et des paramètres de base
    await flutterTts.setLanguage(languageCode);
    flutterTts.setPitch(1.0);
    flutterTts.setSpeechRate(0.6);
    flutterTts.setVolume(1.0);

    // Configuration spécifique selon la plateforme pour forcer la sortie audio sur le haut-parleur
    if (Platform.isIOS) {
      // Pour iOS, on définit la catégorie audio "playAndRecord" avec l'option defaultToSpeaker
      await flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers
        ],
      );
    } else if (Platform.isAndroid) {
      // Pour Android, cette méthode aide à orienter l'audio vers le haut-parleur
      await flutterTts.setAudioAttributesForNavigation();
      // Note : Il peut être nécessaire d'ajouter dans AndroidManifest.xml
      // <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
      // afin de garantir le bon fonctionnement sur certains appareils.
    }

    // Configuration centralisée des callbacks
    flutterTts.setStartHandler(() {
      setState(() {
        isSpeaking = true;
      });
    });
    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
    flutterTts.setErrorHandler((msg) {
      setState(() {
        isSpeaking = false;
      });
      print("Erreur TTS: $msg");
    });
  }

  void _sendMessage(String content) async {
    setState(() {
      _messages.add({
        'role': 'user',
        'content': content,
      });
    });

    try {
      String contextPrompt = "Vous êtes un formateur de vente, en mode One-Shot. L'utilisateur joue le rôle d'un commercial en rendez-vous client. "
          "Votre rôle est d'écouter le commercial, de fournir des retours après chaque interaction, et de le guider naturellement dans la vente. "
          "Réagissez de manière flexible, selon les besoins du commercial. Si le commercial fait une erreur (par exemple, se précipite ou oublie une étape), "
          "corrigez-le et donnez des suggestions. Si le commercial pose des questions, répondez comme un formateur bienveillant, en expliquant comment aborder la situation de manière réaliste.";

      final combinedScript = "$contextPrompt\n$salesScript";

      final response = await _gptService.generateTextBasedOnSalesScript(_messages, combinedScript);
      _addTrainerResponse(response);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la génération de la réponse de l'IA.")));
    }
  }

  void _addTrainerResponse(String response) {
    String cleanResponse = response.replaceAll(RegExp(r'[*]'), '');
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': cleanResponse,
      });
      _speak(cleanResponse);
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
        listenFor: Duration(minutes: 1),
        pauseFor: maxSilence,
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

  // Simule une action qui active/désactive l'animation
  void toggleSpeaking() {
    setState(() {
      isSpeaking = !isSpeaking;
    });
  }

  Future<void> _speak(String text) async {
    try {
      setState(() {
        isSpeaking = true;
      });
      await flutterTts.speak(text);
    } catch (e) {
      print("Erreur lors de la lecture du texte : $e");
      setState(() {
        isSpeaking = false;
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
                padding: EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white70,
                child: Column(
                  children: [
                    SizedBox(height: 50),
                    ElevatedButton.icon(
                      icon: Icon(Icons.ads_click, color: Colors.orangeAccent, size: 24),
                      label: Text(
                        'Clic Terminer'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        _showExitConfirmationDialog(context); // Appel avec le contexte actuel
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade50,
                        shadowColor: Colors.brown.shade200,
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              // Corps principal
              Expanded(
                child: Stack(
                  children: <Widget>[
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
                            controller: _scrollController,
                            itemCount: _messages.length,
                            itemBuilder: (BuildContext context, int index) {
                              final message = _messages[index];
                              final isUserMessage = message['role'] == 'user';
                              final isAssistantMessage = message['role'] == 'assistant';

                              return Column(
                                crossAxisAlignment: isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (isAssistantMessage) ...[
                                    Container(
                                      color: Colors.green[100],
                                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                      padding: const EdgeInsets.all(8.0),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: AssetImage('assets/images/system.png'),
                                          backgroundColor: Colors.grey,
                                        ),
                                        title: Text(
                                          message['content'],
                                          style: TextStyle(fontWeight: FontWeight.normal),
                                        ),
                                        subtitle: Text('Gérant'.tr()),
                                      ),
                                    ),
                                  ],
                                  if (isUserMessage)
                                    Container(
                                      color: Colors.blue[100],
                                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                      padding: const EdgeInsets.all(8.0),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: userProfilePhotoUrl != null
                                              ? NetworkImage(userProfilePhotoUrl!)
                                              : AssetImage('assets/images/default_user.png'),
                                          backgroundColor: Colors.grey,
                                        ),
                                        title: Text(
                                          message['content'],
                                          style: TextStyle(fontWeight: FontWeight.bold),
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
                        icon: Icon(Icons.mic, color: Colors.white, size: 30),
                        label: Text(
                          _isListening ? 'Stop'.tr() : 'Parler'.tr(),
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        onPressed: () {
                          if (_isListening) {
                            _stopListening();
                          } else {
                            _startListening();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: _isListening ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.send, color: Colors.white, size: 30),
                        label: Text(
                          'Valider'.tr(),
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.width * 0.6,
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

      // Générer le compte rendu
      String report = generateLearningReport();

      // Sauvegarder le rapport sous un nom spécifique pour SimulationLearn
      await _saveLearningReportToFirestore(report);

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

  String generateLearningReport() {
    StringBuffer report = StringBuffer();

    // Introduction
    report.writeln("# Compte Rendu de la Simulation d'Apprentissage");
    report.writeln("Voici une analyse détaillée de votre session d'apprentissage :\n");

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
      report.writeln("- Aucun point positif explicite trouvé, mais votre effort est notable !");
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
      report.writeln("- Aucun problème détecté, mais il y a toujours de la place pour affiner vos réponses.");
    }

    // Recommandations
    report.writeln("\n## Recommandations");
    report.writeln("- Donnez des exemples plus spécifiques et concrets.");
    report.writeln("- Posez des questions ouvertes pour explorer davantage les besoins du client.");
    report.writeln("- Soyez précis et concis dans vos réponses.");

    // Conclusion
    report.writeln("\n## Conclusion");
    report.writeln("Votre simulation est prometteuse. Continuez à travailler sur les axes identifiés pour exceller dans vos prochaines interactions.");

    return report.toString();
  }

  Future<void> _saveLearningReportToFirestore(String report) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && report.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('chapters')
            .doc(widget.chapterId)
            .set({
          'learningReport': report,
          'gptMessages': _messages,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print("Rapport d'apprentissage sauvegardé avec succès !");
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

  void _showExitConfirmationDialog(BuildContext context) {

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0), // Bordures arrondies
        ),
        title: Text(
          "Terminer la simulation ?",
          textAlign: TextAlign.center, // Centre le texte du titre
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Voulez-vous terminer la simulation et générer un compte rendu, ou quitter sans générer de compte rendu ?",
              textAlign: TextAlign.center, // Centre le texte du contenu
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDialogButton(
                  context,
                  label: "Annuler",
                  color: Colors.grey,
                  onPressed: () {
                    Navigator.pop(context); // Fermer le dialogue
                  },
                ),
                _buildDialogButton(
                  context,
                  label: "Générer le compte rendu",
                  color: Colors.blue,
                  onPressed: () async {
                    Navigator.pop(context); // Fermer le dialogue
                    await _generateAndSaveReport(); // Générer le rapport
                  },
                ),
                _buildDialogButton(
                  context,
                  label: "Quitter",
                  color: Colors.red,
                  onPressed: () {
                    Navigator.pop(context); // Fermer le dialogue
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/levels', // Remplacez '/levels' par la route de votre écran d'accueil
                          (Route<dynamic> route) => false,
                    ); // Naviguer vers l'écran d'accueil en supprimant toutes les routes précédentes
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogButton(
      BuildContext context, {
        required String label,
        required Color color,
        required VoidCallback onPressed,
      }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color, // Couleur de fond du bouton
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0), // Bordures arrondies
            ),
            padding: EdgeInsets.symmetric(vertical: 12.0), // Hauteur du bouton
          ),
          onPressed: onPressed,
          child: Text(
            label,
            textAlign: TextAlign.center,
          ),
        ),
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

      final reportPrompt = """
    Vous êtes un formateur en vente. Voici les interactions enregistrées :
    ${_messages.map((m) => "${m['role']}: ${m['content']}").join("\n")}

    Générer un compte rendu clair avec :
    - Les points positifs
    - Les axes d'amélioration
    - Des recommandations pratiques.
    """;

      final report = await _gptService.generateText([
        {
          'role': 'system',
          'content': 'Générez un compte rendu structuré et détaillé basé sur ces interactions.'
        },
        {'role': 'user', 'content': reportPrompt},
      ]);

      await _saveLearningReportToFirestore(report);

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
      print("Erreur lors de la génération du compte rendu : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la génération du compte rendu.")),
      );
    }
  }
}
