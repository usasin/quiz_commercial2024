import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../theme/cip_colors.dart' as c;
import '../services/openai_roleplay_service.dart';
import '../services/review_service.dart';
import '../services/usage_meter.dart';
import '../services/engagement_service.dart';
import '../services/admob_interstitial_service.dart';
import '../services/app_language.dart';
import '../screens/credits_paywall_page.dart';
import 'simulator_write_page.dart';

/// ResultPage = feedback ORAL (coach) + étape écrits.
/// ✅ Les feedbacks ÉCRITS (synthèse + analyse) sont affichés ici après validation.
/// ✅ Partage visible en bas, grisé tant que:
///   - écrits pas terminés OU
///   - pas premium ET pas “avis donné” (déblocage partage via popup)
class SimulatorResultPage extends StatefulWidget {
  final String chapterId;
  final String moduleId;
  final String moduleTitle;

  final String scenarioId;
  final String scenarioTitle;
  final Map<String, dynamic> persona;
  final List<Map<String, String>> transcript;

  /// Feedback ORAL (coach)
  final Map<String, dynamic> feedback;

  /// Service IA (pour ouvrir la page écrits)
  final OpenAiRoleplayService? service;
  final Map<String, dynamic> scenarioData;
  final String? trainingSessionId;

  /// Optional: decides which video to show (or none)
  final String? resultKind; // "pass" | "moduleWin" | "fail" | null

  const SimulatorResultPage({
    super.key,
    required this.chapterId,
    required this.moduleId,
    required this.moduleTitle,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.persona,
    required this.transcript,
    required this.feedback,
    this.service,
    this.scenarioData = const <String, dynamic>{},
    this.trainingSessionId,
    this.resultKind,
  });

  @override
  State<SimulatorResultPage> createState() => _SimulatorResultPageState();
}

class _SimulatorResultPageState extends State<SimulatorResultPage> {
  // --- Video (optional)
  VideoPlayerController? _vc;
  Future<void>? _videoInitFuture;
  String? _videoUrl;
  bool _videoLoading = false;

  // --- Écrits
  bool _writingDone = false;
  Map<String, dynamic>? _synthResult;
  Map<String, dynamic>? _analysisResult;

  // --- Partage
  bool _shareUnlockedByReview = false;
  bool _checkingPremium = true;
  bool _isPremium = false;
  bool _simulationAdAlreadyTried = false;

  @override
  void initState() {
    super.initState();
    _maybeLoadResultVideo();
    _loadPremiumState();

    // ✅ Précharge l'interstitiel de simulation pour la fermeture de la page résultat.
    AdmobInterstitialService.instance.preloadSimulation();
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _loadPremiumState() async {
    try {
      final meter = UsageMeter();
      await meter.initIfNeeded();
      final p = await meter.isPremium();
      if (!mounted) return;
      setState(() {
        _isPremium = p;
        _checkingPremium = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingPremium = false);
    }
  }

  // -------------------- helpers safe

  int _safeInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  List<String> _safeList(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _asScoreOral() {
    final v = widget.feedback['score'];
    if (v == null) return '--';
    if (v is num) return v.toInt().toString();
    return v.toString();
  }

  // -------------------- video (optional)

  Future<void> _maybeLoadResultVideo() async {
    final kind = widget.resultKind?.trim();
    if (kind == null || kind.isEmpty) return;

    setState(() => _videoLoading = true);

    try {
      final modDoc = await FirebaseFirestore.instance
          .collection('chapters')
          .doc(widget.chapterId)
          .collection('modules')
          .doc(widget.moduleId)
          .get();

      final data = modDoc.data();
      final rv = data?['resultVideos'];

      if (rv is! Map) {
        if (mounted) setState(() => _videoLoading = false);
        return;
      }

      final path = (rv[kind] ?? '').toString().trim();
      if (path.isEmpty) {
        if (mounted) setState(() => _videoLoading = false);
        return;
      }

      final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
      _videoUrl = url;

      _vc = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoInitFuture = _vc!.initialize().then((_) {
        _vc!.setLooping(true);
        _vc!.play();
        if (mounted) setState(() {});
      });

      if (mounted) setState(() => _videoLoading = false);
    } catch (_) {
      if (mounted) setState(() => _videoLoading = false);
    }
  }

  Widget _videoBlock() {
    if (widget.resultKind == null) return const SizedBox.shrink();

    if (_videoLoading) {
      return _card(
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.bilingual(
                  fr: 'Chargement de la vidéo…',
                  en: 'Loading video…',
                ),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    if (_videoUrl == null || _vc == null || _videoInitFuture == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<void>(
      future: _videoInitFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _card(child: const LinearProgressIndicator());
        }
        final v = _vc!;
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.bilingual(fr: '🎬 Résultat', en: '🎬 Result'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: v.value.aspectRatio <= 0
                      ? (16 / 9)
                      : v.value.aspectRatio,
                  child: VideoPlayer(v),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (v.value.isPlaying) {
                          v.pause();
                        } else {
                          v.play();
                        }
                      });
                    },
                    icon: Icon(
                      v.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await v.seekTo(Duration.zero);
                      await v.play();
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.replay_rounded),
                  ),
                  const Spacer(),
                  Text(
                    widget.resultKind == 'moduleWin'
                        ? context.bilingual(
                            fr: 'Module gagné',
                            en: 'Module completed',
                          )
                        : (widget.resultKind == 'pass'
                              ? context.bilingual(fr: 'Bravo', en: 'Well done')
                              : context.bilingual(
                                  fr: 'À refaire',
                                  en: 'Try again',
                                )),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- navigation écrits

  Future<void> _goToWriting() async {
    if (widget.service == null) {
      _snack(
        context.bilingual(
          fr: 'Service IA non fourni. Reviens à la simulation et réessaie.',
          en: 'AI service unavailable. Return to the simulation and try again.',
        ),
      );
      return;
    }

    // SimulatorWritingPage renvoie:
    // { "done": true, "synthesis": <Map>, "analysis": <Map> }
    final pack = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SimulatorWritingPage(
          scenarioId: widget.scenarioId,
          persona: widget.persona,
          transcript: widget.transcript,
          service: widget.service!,
          moduleTitle: widget.moduleTitle,
          scenarioTitle: widget.scenarioTitle,
          scenarioData: widget.scenarioData,
          trainingSessionId: widget.trainingSessionId,
        ),
      ),
    );

    if (!mounted) return;
    if (pack == null) return;

    final done = (pack['done'] == true);
    if (!done) return;

    setState(() {
      _writingDone = true;
      _synthResult = (pack['synthesis'] is Map)
          ? Map<String, dynamic>.from(pack['synthesis'])
          : null;
      _analysisResult = (pack['analysis'] is Map)
          ? Map<String, dynamic>.from(pack['analysis'])
          : null;
    });

    // ✅ Marque la simu comme "faite" (déblocage du module suivant)
    await _markSimulationDoneAndGamify();

    _snack(
      context.bilingual(
        fr: '✅ Écrits terminés — Feedback complet débloqué.',
        en: '✅ Writing completed — Full feedback unlocked.',
      ),
    );
  }

  Future<void> _markSimulationDoneAndGamify() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final key = '${widget.chapterId}::${widget.moduleId}';
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'simuDone': {key: true},
        'lastSimuAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // On ne bloque pas l'UI si Firestore a un souci
    }

    final oralScore = _safeInt(widget.feedback['score']);

    // ✅ Gamification: streak + badges + XP
    await EngagementService.recordSimulationCompleted(
      oralScore: oralScore,
      activityId: widget.scenarioId,
    );
  }

  // -------------------- partage + gate avis/premium

  bool get _shareEnabled {
    if (!_writingDone) return false;
    if (_checkingPremium) return false;
    if (_isPremium) return true;
    return _shareUnlockedByReview;
  }

  Future<void> _ensureShareUnlocked() async {
    if (!_writingDone) {
      _snack(
        context.bilingual(
          fr: 'Termine d’abord les écrits pour débloquer le partage.',
          en: 'Complete the writing tasks first to unlock sharing.',
        ),
      );
      return;
    }
    if (_checkingPremium) return;
    if (_isPremium) return;
    if (_shareUnlockedByReview) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          context.bilingual(fr: 'Débloquer le partage', en: 'Unlock sharing'),
        ),
        content: Text(
          context.bilingual(
            fr: 'Donne ton avis pour débloquer le partage.\n\nOu passe Premium pour tout débloquer.',
            en: 'Leave a review to unlock sharing.\n\nOr upgrade to Premium to unlock everything.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, "close"),
            child: Text(context.bilingual(fr: 'Plus tard', en: 'Later')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, "premium"),
            child: Text(
              context.bilingual(fr: 'Passer Premium', en: 'Upgrade to Premium'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, "review"),
            child: Text(
              context.bilingual(fr: 'Donner un avis', en: 'Leave a review'),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (choice == "premium") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreditsPaywallPage()),
      );
      return;
    }

    if (choice == "review") {
      // ✅ on déclenche la demande d’avis (ReviewService garde ses propres règles)
      await ReviewService().maybeAskReview();
      if (!mounted) return;

      // ✅ déblocage simple (UX). Si tu veux “vérifier”, il faudrait une vraie persistence côté user.
      setState(() => _shareUnlockedByReview = true);
      _snack(
        context.bilingual(
          fr: '✅ Merci ! Partage débloqué.',
          en: '✅ Thank you! Sharing unlocked.',
        ),
      );
    }
  }

  String _buildShareText() {
    final scoreOral = _asScoreOral();

    final oralStrengths = _safeList(widget.feedback['strengths']);
    final oralImprovements = _safeList(widget.feedback['improvements']);
    final oralMissing = _safeList(widget.feedback['missingQuestions']);

    final synthNote = _synthResult == null
        ? null
        : _safeInt(_synthResult!['note']);
    final analysisNote = _analysisResult == null
        ? null
        : _safeInt(_analysisResult!['note']);

    final b = StringBuffer();
    b.writeln(
      '${context.bilingual(fr: '📌 Résultat', en: '📌 Result')} — ${widget.moduleTitle}',
    );
    b.writeln(
      '${context.bilingual(fr: 'Simulation', en: 'Simulation')}: ${widget.scenarioTitle}',
    );
    b.writeln("");

    b.writeln("🗣️ ORAL (coach)");
    b.writeln(
      '${context.bilingual(fr: 'Score oral', en: 'Speaking score')}: $scoreOral/100',
    );
    if (oralStrengths.isNotEmpty) {
      b.writeln(context.bilingual(fr: '✅ Points forts :', en: '✅ Strengths:'));
      for (final s in oralStrengths.take(8)) b.writeln("• $s");
    }
    if (oralImprovements.isNotEmpty) {
      b.writeln(
        context.bilingual(fr: '⚠️ À améliorer :', en: '⚠️ Areas to improve:'),
      );
      for (final s in oralImprovements.take(8)) b.writeln("• $s");
    }
    if (oralMissing.isNotEmpty) {
      b.writeln(
        context.bilingual(
          fr: '❓ Questions oubliées :',
          en: '❓ Missed questions:',
        ),
      );
      for (final s in oralMissing.take(8)) b.writeln("• $s");
    }

    if (_writingDone) {
      b.writeln("");
      b.writeln(context.bilingual(fr: '✍️ ÉCRITS', en: '✍️ WRITING'));
      if (synthNote != null) {
        b.writeln(
          '${context.bilingual(fr: 'Synthèse', en: 'Summary')}: $synthNote/100',
        );
      }
      if (analysisNote != null) {
        b.writeln(
          '${context.bilingual(fr: 'Analyse', en: 'Analysis')}: $analysisNote/100',
        );
      }
    }

    b.writeln("");
    b.writeln("— EmploiBoost");
    return b.toString().trim();
  }

  Future<void> _copy() async {
    await _ensureShareUnlocked();
    if (!_shareEnabled) return;

    await Clipboard.setData(ClipboardData(text: _buildShareText()));
    if (!mounted) return;
    _snack(context.bilingual(fr: 'Copié ✅', en: 'Copied ✅'));
  }

  Future<void> _share() async {
    await _ensureShareUnlocked();
    if (!_shareEnabled) return;

    await Share.share(_buildShareText());
  }

  // -------------------- UI atoms

  Future<void> _closeResultPage() async {
    if (!_simulationAdAlreadyTried) {
      _simulationAdAlreadyTried = true;
      try {
        await AdmobInterstitialService.instance.showSimulationAdIfAvailable();
      } catch (_) {
        // On ne bloque jamais la fermeture de la page à cause d'une pub.
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pill({required String text, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w900, color: fg, fontSize: 12),
      ),
    );
  }

  Widget _listBlock({
    required String title,
    required IconData icon,
    required Color accent,
    required List<String> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text("—", style: TextStyle(color: Color(0xFF6B7280)))
          else
            for (final x in items.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("• $x"),
              ),
        ],
      ),
    );
  }

  Widget _writtenBlock(String title, Map<String, dynamic> r) {
    final note = _safeInt(r['note']);
    final ok = _safeList(r['ok']);
    final bad = _safeList(r['a_corriger']);
    final prop = (r['proposition'] ?? '').toString().trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              _pill(
                text: "$note/100",
                bg: c.cipGreen.withOpacity(0.12),
                fg: c.cipGreen,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text("✅ OK", style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          if (ok.isEmpty)
            const Text("—", style: TextStyle(color: Color(0xFF6B7280))),
          for (final x in ok.take(8)) Text("• $x"),
          const SizedBox(height: 10),
          Text(
            context.bilingual(fr: '⚠️ À corriger', en: '⚠️ Needs improvement'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          if (bad.isEmpty)
            const Text("—", style: TextStyle(color: Color(0xFF6B7280))),
          for (final x in bad.take(8)) Text("• $x"),
          if (prop.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.bilingual(
                fr: '✍️ Proposition',
                en: '✍️ Suggested answer',
              ),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(prop),
          ],
        ],
      ),
    );
  }

  // -------------------- BUILD

  @override
  Widget build(BuildContext context) {
    final scoreOral = _asScoreOral();

    final strengths = _safeList(widget.feedback['strengths']);
    final improvements = _safeList(widget.feedback['improvements']);
    final missing = _safeList(widget.feedback['missingQuestions']);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black45,
          ),
          onPressed: _closeResultPage,
        ),
        title: null,
        actions: [
          TextButton(
            onPressed: _closeResultPage,
            child: Text(
              context.bilingual(fr: 'FERMER', en: 'CLOSE'),
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Header comme OralPage
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
            color: Colors.white,
            child: Column(
              children: [
                Text(
                  widget.moduleTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: c.cipBlue,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.scenarioTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                _videoBlock(),

                // Étape suivante (écrits)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.cipBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.cipBlue.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school_rounded, color: c.cipBlue),
                          const SizedBox(width: 8),
                          Text(
                            context.bilingual(
                              fr: 'Étape suivante',
                              en: 'Next step',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.bilingual(
                          fr: 'Tu as terminé l’oral.\n\n👉 Maintenant, passe à l’écrit :\n• Synthèse\n• Analyse\n\nLe résultat final (oral + écrits) s’affichera ici.',
                          en: 'You completed the speaking task.\n\n👉 Now move on to writing:\n• Summary\n• Analysis\n\nYour final result (speaking + writing) will appear here.',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.cipGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.edit_rounded),
                          label: Text(
                            _writingDone
                                ? context.bilingual(
                                    fr: 'Écrits terminés ✅',
                                    en: 'Writing completed ✅',
                                  )
                                : context.bilingual(
                                    fr: 'Passer aux écrits',
                                    en: 'Continue to writing',
                                  ),
                          ),
                          onPressed: _writingDone ? null : _goToWriting,
                        ),
                      ),
                    ],
                  ),
                ),

                // Score oral (simple)
                _card(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: c.cipBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.mic_rounded, color: c.cipBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.bilingual(
                            fr: 'Feedback ORAL (coach)',
                            en: 'SPEAKING feedback (coach)',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _pill(
                        text: "$scoreOral/100",
                        bg: c.cipGreen.withOpacity(0.12),
                        fg: c.cipGreen,
                      ),
                    ],
                  ),
                ),

                // Oral feedback
                _listBlock(
                  title: context.bilingual(
                    fr: 'Points forts (oral)',
                    en: 'Strengths (speaking)',
                  ),
                  icon: Icons.check_circle_rounded,
                  accent: c.cipGreen,
                  items: strengths,
                ),
                _listBlock(
                  title: context.bilingual(
                    fr: 'À améliorer (oral)',
                    en: 'Areas to improve (speaking)',
                  ),
                  icon: Icons.warning_rounded,
                  accent: const Color(0xFFF59E0B),
                  items: improvements,
                ),
                _listBlock(
                  title: context.bilingual(
                    fr: 'Questions oubliées (oral)',
                    en: 'Missed questions (speaking)',
                  ),
                  icon: Icons.help_rounded,
                  accent: c.cipBlue,
                  items: missing,
                ),

                const SizedBox(height: 6),

                // Écrits feedback
                if (!_writingDone)
                  _card(
                    child: Text(
                      context.bilingual(
                        fr: '🔒 Feedback ÉCRITS verrouillé.\nTermine la synthèse + l’analyse pour afficher le résultat final.',
                        en: '🔒 WRITING feedback locked.\nComplete the summary and analysis to view your final result.',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                        height: 1.35,
                      ),
                    ),
                  ),

                if (_writingDone) ...[
                  _card(
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: c.cipBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            color: c.cipBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.bilingual(
                              fr: 'Feedback ÉCRITS',
                              en: 'WRITING feedback',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _pill(
                          text: context.bilingual(
                            fr: 'Débloqué',
                            en: 'Unlocked',
                          ),
                          bg: c.cipGreen.withOpacity(0.12),
                          fg: c.cipGreen,
                        ),
                      ],
                    ),
                  ),
                  if (_synthResult != null)
                    _writtenBlock(
                      context.bilingual(fr: 'Synthèse', en: 'Summary'),
                      _synthResult!,
                    ),
                  if (_analysisResult != null)
                    _writtenBlock(
                      context.bilingual(fr: 'Analyse', en: 'Analysis'),
                      _analysisResult!,
                    ),
                ],

                const SizedBox(height: 6),

                // Partage (visible, mais grisé)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareEnabled ? _copy : _ensureShareUnlocked,
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(
                          context.bilingual(fr: 'Copier', en: 'Copy'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.cipBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _shareEnabled
                            ? _share
                            : _ensureShareUnlocked,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(
                          _shareEnabled
                              ? context.bilingual(fr: 'Partager', en: 'Share')
                              : context.bilingual(
                                  fr: 'Partager (verrouillé)',
                                  en: 'Share (locked)',
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
