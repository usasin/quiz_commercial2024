// lib/screens/simulation_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';                       // ← nouveau

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../services/gpt_service.dart';
import '../rotating_glow_border.dart';
import '../animated_gradient_button.dart';
import 'compte_rendu_screen.dart';
import 'levels_page.dart';

class SimulationScreen extends StatefulWidget {
  final String chapterId;
  final bool guided; // true = Mode Apprenant

  const SimulationScreen({
    required this.chapterId,
    this.guided = true,
    Key? key,
  }) : super(key: key);

  const SimulationScreen.free({required String chapterId, Key? key})
      : this(chapterId: chapterId, guided: false, key: key);

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  /* ─── Services ─── */
  final _gpt = GptService();
  final _recorder = FlutterSoundRecorder();
  final _player = AudioPlayer();
  final _scroller = ScrollController();
  final _inputCtl = TextEditingController();

  /* ─── États ─── */
  bool _recInit = false;
  bool _recording = false;
  bool _speaking = false;
  bool _savingReport = false;

  /* ─── Script ─── */
  String chapterTitle = '';
  String aiRole = '';
  List<dynamic> stepList = [];
  int _currentStep = 0;
  late List<String> _stepStatus; // pending | correct | partial | missing
  late List<int> _attempts;

  /* ─── Prospect aléatoire ─── */
  final _rng = Random();             // ← nouveau
  String _prospectPersona = '';      // ← nouveau

  /* ─── Historique chat ─── */
  final _messages = <Map<String, String>>[];

  /* ═════════ INIT ═════════ */
  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadChapter().then((_) => _welcome());
  }

  Future<void> _initRecorder() async {
    if (await Permission.microphone.request().isGranted) {
      await _recorder.openRecorder();
      _recInit = true;
    }
  }

  Future<void> _loadChapter() async {
    final doc = await FirebaseFirestore.instance
        .collection('chapters')
        .doc(widget.chapterId)
        .get();

    final fileName = doc.data()?['scriptFile'] ?? '${widget.chapterId}.json';
    final path = 'assets/scripts/$fileName';

    try {
      final jsonStr = await rootBundle.loadString(path);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      stepList = (data['steps'] as List<dynamic>?) ?? [];
      if (stepList.isEmpty) {
        stepList = [
          {'id': 'Libre', 'goal': 'Répondre librement', 'mustSay': []}
        ];
      }

      // ----------- nouveau : choisir un profil prospect -----------
      final profiles = (data['prospectProfiles'] as List<dynamic>?) ?? [];
      if (profiles.isNotEmpty) {
        _prospectPersona = profiles[_rng.nextInt(profiles.length)];
      } else {
        _prospectPersona = "Vous hésitez encore pour des raisons personnelles.";
      }
      // ------------------------------------------------------------

      setState(() {
        chapterTitle = data['title'] ?? 'Script';
        aiRole = data['aiRole'] ?? 'le prospect';
        _stepStatus = List.filled(stepList.length, 'pending');
        _attempts = List.filled(stepList.length, 0);
      });
    } catch (_) {
      setState(() {
        chapterTitle = 'Script introuvable';
        stepList = [
          {'id': 'Libre', 'goal': 'Répondre librement', 'mustSay': []}
        ];
        _stepStatus = ['pending'];
        _attempts = [0];
        _prospectPersona =
        "Vous hésitez encore pour des raisons personnelles."; // valeur de secours
      });
    }
  }
/* ═════════ PROMPT ═════════ */
  /// Construit le prompt système envoyé à OpenAI.
  /// - Mode LIBRE : le modèle n’incarne que le prospect.
  /// - Mode APPRENANT : le modèle incarne le prospect **et** un Coach formateur
  ///   qui vérifie les mots-clés obligatoires et corrige le commercial.
  String _systemPrompt() {
    /* ─── MODE LIBRE ─── */
    if (!widget.guided) {
      return '''
Tu es **${aiRole.toLowerCase()}**.  
Profil du prospect : $_prospectPersona  
Mode LIBRE : réagis comme un client réel, intéressé mais encore indécis ; exprime tes doutes, pose des questions.  
Si tu es convaincu, signe ou propose un rendez-vous.  
Pas de conseils ni d’évaluation.
''';
    }

    /* ─── MODE APPRENANT ─── */
    final step       = stepList[_currentStep];
    final keywords   = (step['mustSay'] as List).join(", ");
    final tentatives = _attempts[_currentStep] + 1;
    final aide       = switch (tentatives) {
      2 => 'Donne un indice pratique (ex. poser une question suggestive).',
      3 => 'Propose une phrase exemple complète qui intègre les mots-clés manquants.',
      _ => ''
    };

    return '''
Ton objectif : aider le commercial à réussir **chaque étape** du script.

**Règles Coach :**
• Après CHAQUE réponse du commercial, vérifie si TOUS les mots-clés obligatoires de l’étape sont présents  
  → Mots-clés attendus : $keywords  
• Fais un retour en 2 phrases maxi :  
  1) Feedback positif ou neutre + ce qui manque ➜ liste claire des mots-clés absents.  
  2) Suggestion concrète pour corriger (reformulation ou question à poser).  
• Termine toujours par l’emoji ✅ (tous mots-clés OK) ou ⚠️ (il en manque) ou ❌ (hors sujet).  
• Si ⚠️ ou ❌ : invite le commercial à recommencer ET $aide

**Rôle prospect (${aiRole.toLowerCase()})** :  
Réponds de façon réaliste, intéressé mais indécis, cohérente avec le **profil aléatoire** : $_prospectPersona  
Si le commercial couvre bien les besoins et répond aux objections : accepte de conclure ou fixe un rendez-vous clair.

Réponds toujours en français.  
Indique la partie Coach **entre parenthèses** à la fin de ta réponse.
Étape en cours : « ${step['id']} » – Objectif : ${step['goal']}.
''';
  }


  /* ═════════ ENREGISTREMENT ═════════ */
  Future<void> _startRec() async {
    if (!_recInit) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.startRecorder(
        toFile: path, codec: Codec.aacMP4, sampleRate: 16000, numChannels: 1);
    setState(() => _recording = true);
  }

  Future<void> _stopRec() async {
    final path = await _recorder.stopRecorder();
    setState(() => _recording = false);
    if (path == null) return;

    final file = File(path);
    if (file.lengthSync() == 0) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final txt = await _gpt.transcribeAudio(file);
      if (!mounted) return;
      Navigator.pop(context);
      _sendUser(txt);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Transcription KO : $e')));
    }
  }

  /* ═════════ CHAT ═════════ */
  void _sendUser(String content) {
    _messages.add({'role': 'user', 'content': content});
    setState(() {});
    _scroll();
    _callGPT();
  }

  Future<void> _callGPT() async {
    final apiMsgs = _messages
        .map((m) => {
      'role': m['role'] == 'user' ? 'user' : 'assistant',
      'content': m['content']!
    })
        .toList();

    late String raw;
    try {
      raw = await _gpt.generateText(
        [
          {'role': 'system', 'content': _systemPrompt()},
          ...apiMsgs
        ],
        model: 'gpt-4o-mini',
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur GPT : $e')));
      return;
    }

    // 2) split prospect / coach
    String prospect = raw, coach = '';
    if (widget.guided) {
      final m = RegExp(r'\((.*?)\)$', dotAll: true).firstMatch(raw);
      if (m != null) {
        prospect = raw.replaceFirst(m.group(0)!, '').trim();
        coach = m.group(1)!.trim();
      }
    }

    _messages.add({'role': 'assistant-prospect', 'content': prospect});
    if (coach.isNotEmpty) {
      _messages.add({'role': 'assistant-coach', 'content': coach});
    }

    // 3) marqueur
    String marker = '';
    if (coach.contains('✅')) {
      marker = 'correct';
    } else if (coach.contains('⚠️')) {
      marker = 'partial';
    } else if (coach.contains('❌')) {
      marker = 'missing';
    }
    if (widget.guided && marker.isNotEmpty) {
      _stepStatus[_currentStep] = marker;
    }

    setState(() {});
    _scroll();
    _tts(raw);

    // 4) progression & auto-save
    if (widget.guided) {
      if (marker == 'correct') {
        await _autoSave();
        if (_currentStep < stepList.length - 1) {
          setState(() => _currentStep++);
        }
      } else if (marker.isNotEmpty) {
        _attempts[_currentStep]++;
      }
    }
  }

  /* ═════════ AUTO-SAVE ═════════ */
  Future<void> _autoSave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final statusField = widget.guided ? 'stepStatusGuide' : 'stepStatusLibre';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chapters')
        .doc(widget.chapterId)
        .set({statusField: _stepStatus}, SetOptions(merge: true));
  }

  /* ═════════ TTS ═════════ */
  Future<void> _tts(String text) async {
    setState(() => _speaking = true);
    final f = await _gpt.synthesizeSpeech(text);
    await _player.play(DeviceFileSource(f.path));
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _speaking = false);
    });
  }

  void _scroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroller.hasClients) {
        _scroller.animateTo(_scroller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  /* ═════════ WELCOME ═════════ */
  void _welcome() {
    final mode = widget.guided ? 'Mode Apprenant' : 'Mode Libre';
    _messages.add({
      'role': 'assistant-prospect',
      'content':
      'Bienvenue dans le $mode de la simulation « $chapterTitle ». Clique sur le micro pour parler.'
    });
    setState(() {});
  }

  /* ═════════ RAPPORT ═════════ */
  Future<String> _evaluate() async {
    final hist =
    _messages.map((m) => "${m['role']}: ${m['content']}").join('\n');
    try {
      return await _gpt.generateText([
        {
          'role': 'system',
          'content':
          'Tu es un formateur. Pour chaque étape indique ✅/⚠️/❌ et donne 3 conseils.'
        },
        {'role': 'user', 'content': hist},
      ]);
    } catch (e) {
      return 'Erreur analyse : $e';
    }
  }

  Future<void> _saveReport() async {
    setState(() => _savingReport = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Navigator.pop(context);
      setState(() => _savingReport = false);
      return;
    }
    final report = await _evaluate();

    final reportField = widget.guided ? 'learningReport' : 'interviewReport';
    final statusField = widget.guided ? 'stepStatusGuide' : 'stepStatusLibre';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chapters')
        .doc(widget.chapterId)
        .set({
      reportField: report,
      statusField: _stepStatus,
      'messages': _messages,
      'timestamp': FieldValue.serverTimestamp(),
      'prospectPersona': _prospectPersona,   // ← facultatif : sauvegarde
    }, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.pop(context); // close loading dialog
    setState(() => _savingReport = false);

    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                CompteRenduScreen(chapterId: widget.chapterId)));
  }

  /* ═════════ UI ═════════ */
  String get _modeLabel => widget.guided ? 'Mode Apprenant' : 'Mode Libre';

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child: Column(children: [
        _header(),
        Expanded(child: _chat()),
      ]),
    ),
    bottomNavigationBar: _bottom(),
  );

  Widget _header() => Container(
    padding: const EdgeInsets.all(16),
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AutoSizeText(
          chapterTitle,
          style:
          const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        AutoSizeText(
          _modeLabel,
          style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey),
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (widget.guided) _timeline(),
        const SizedBox(height: 8),
        const Text(
          'Cliquez sur « Terminer » pour générer votre compte-rendu.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedGradientButton(
              child: Row(
                children: [
                  const Icon(Icons.done, color: Colors.white),
                  const SizedBox(width: 6),
                  AutoSizeText(
                    'Terminer',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 1,
                  ),
                ],
              ),
              onTap: _savingReport ? null : _saveReport,
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.exit_to_app),
              label: const AutoSizeText('Quitter', maxLines: 1),
              onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LevelsPage())),
            ),
          ],
        )
      ],
    ),
  );

  Widget _timeline() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(stepList.length, (i) {
        Color c;
        String txt;
        switch (_stepStatus[i]) {
          case 'correct':
            c = Colors.green;
            txt = '✓';
            break;
          case 'partial':
            c = Colors.orange;
            txt = '⚠️';
            break;
          case 'missing':
            c = Colors.red;
            txt = '✗';
            break;
          default:
            c = Colors.grey;
            txt = '${i + 1}';
        }
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Column(
            children: [
              RotatingGlowBorder(
                borderWidth: 3,
                borderRadius: 8,
                colors: [Colors.white, c, Colors.white],
                duration: const Duration(seconds: 4),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.withOpacity(.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: AutoSizeText(
                    txt,
                    style: TextStyle(
                        color: c,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 48,
                child: AutoSizeText(
                  stepList[i]['id'],
                  textAlign: TextAlign.center,
                  style:
                  const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        );
      }),
    ),
  );

  Widget _chat() => Stack(children: [
    Opacity(
        opacity: 0.2,
        child: Image.asset('assets/images/background_concours.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity)),
    Column(children: [
      Expanded(
          child: ListView.builder(
              controller: _scroller,
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final role = m['role'];
                Alignment a;
                Color col;
                if (role == 'user') {
                  a = Alignment.centerRight;
                  col = Colors.blue[100]!;
                } else if (role == 'assistant-prospect') {
                  a = Alignment.centerLeft;
                  col = Colors.green[100]!;
                } else {
                  a = Alignment.centerLeft;
                  col = Colors.purple[100]!;
                }
                return Align(
                  alignment: a,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: RotatingGlowBorder(
                      borderWidth: 2,
                      borderRadius: 12,
                      colors: [
                        Colors.white,
                        col.withOpacity(0.6),
                        Colors.white
                      ],
                      duration: const Duration(seconds: 5),
                      child: Container(
                        margin:
                        const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: col,
                            borderRadius: BorderRadius.circular(12)),
                        constraints:
                        const BoxConstraints(maxWidth: 280),
                        child: AutoSizeText(
                          m['content'] ?? '',
                          style: TextStyle(
                              fontStyle: role == 'assistant-coach'
                                  ? FontStyle.italic
                                  : null),
                          maxLines: 5,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                );
              })),
      Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
                child: TextField(
                    controller: _inputCtl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Tapez ici…'))),
            IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  final t = _inputCtl.text.trim();
                  if (t.isNotEmpty) {
                    _inputCtl.clear();
                    _sendUser(t);
                  }
                })
          ]))
    ]),
    if (_speaking)
      Center(
        child: Lottie.asset(
          'assets/parler.json',
          width: 220,
          height: 200,
          repeat: true,
        ),
      ),
  ]);

  Widget _bottom() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: RotatingGlowBorder(
        borderWidth: _recording ? 3 : 0,
        borderRadius: 12,
        colors: _recording
            ? [Colors.white, Colors.greenAccent, Colors.white]
            : [
          Colors.transparent,
          Colors.transparent,
          Colors.transparent
        ],
        duration: const Duration(seconds: 3),
        child: AnimatedGradientButton(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_recording ? Icons.stop : Icons.mic,
                  color: Colors.white, size: 28),
              const SizedBox(width: 8),
              AutoSizeText(
                _recording ? 'Arrêter'.tr() : 'Parler'.tr(),
                style: const TextStyle(fontSize: 18, color: Colors.white),
                maxLines: 1,
              ),
            ],
          ),
          onTap: _recording ? _stopRec : _startRec,
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _recorder.closeRecorder();
    _scroller.dispose();
    _player.dispose();
    _inputCtl.dispose();
    super.dispose();
  }
}
