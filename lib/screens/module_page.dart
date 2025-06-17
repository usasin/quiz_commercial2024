import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:html/parser.dart' as html_parser;

import '../drawer/custom_bottom_nav_bar.dart';
import '../rotating_glow_border.dart';
import 'levels_page.dart';
import 'lessons_screen.dart';

// ───────────────────────── Helpers ─────────────────────────
/// Nettoie un fragment HTML pour le Text-to-Speech : supprime les balises,
/// retire (la plupart) des emojis et compacte les espaces.
String htmlToPlainText(String html) {
  final document = html_parser.parse(html);
  var text = document.body?.text.trim() ?? '';
  final emojiRegex = RegExp(
    r'(\u00a9|\u00ae|[\u2000-\u3300]|[\ud83c\ud000-\ud83c\udfff]|[\ud83d\ud000-\ud83d\udfff]|[\ud83e\ud000-\ud83e\udfff])',
  );
  text = text.replaceAll(emojiRegex, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

// ───────────────────────── Page principale ─────────────────────────
class ModulePage extends StatefulWidget {
  final String moduleId;
  final int parcoursNumber;
  final String chapterId;

  const ModulePage({
    super.key,
    required this.moduleId,
    required this.chapterId,
    required this.parcoursNumber,
  });

  @override
  State<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> {
  late final PageController _pageController;
  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  final ValueNotifier<int> _totalPages = ValueNotifier<int>(0);

  // ───────────── Callbacks nav vers quiz & liste ─────────────
  void _goQuiz() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelsPage()));

  void _goList() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) =>  LessonsScreen()));

  @override
  void initState() {
    super.initState();
    _pageController = PageController()
      ..addListener(() {
        if (_pageController.hasClients && _pageController.page != null) {
          final newPage = _pageController.page!.round();
          if (_currentPage.value != newPage) {
            _tts.stop();
            _currentPage.value = newPage;
          }
        }
      });

    _tts
      ..setLanguage('fr-FR')
      ..setSpeechRate(0.46)
      ..awaitSpeakCompletion(true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tts.stop();
    super.dispose();
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF2F2F2), Colors.white],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,

        // ─── BARRE HAUTE PERSONNALISÉE ──────────────────────────────────
        appBar: _NavigationBar(
          onBack: () => _pageController.previousPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          ),
          onForward: () => _pageController.nextPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          ),
          onGoQuiz: _goQuiz,
          onGoList: _goList,
        ),

        body: SafeArea(
          top: false, // ← AppBar occupe déjà le SafeArea du haut
          child: Column(
            children: [
              _ProgressBar(current: _currentPage, total: _totalPages),
              Expanded(child: _buildLessons()),
            ],
          ),
        ),

        bottomNavigationBar: CustomBottomNavBar(
          parentContext: context,
          currentIndex: 2,
          scaffoldKey: GlobalKey<ScaffoldState>(),
        ),
      ),
    );
  }

  Widget _buildLessons() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lessons')
          .doc(widget.moduleId)
          .collection('lessons')
          .orderBy('lessonNumber')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Une erreur s\'est produite'.tr()));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final lessons = snapshot.data?.docs ?? [];
        _totalPages.value = lessons.length;

        return PageView.builder(
          controller: _pageController,
          itemCount: lessons.length,
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            return _LessonContent(lesson: lesson, tts: _tts);
          },
        );
      },
    );
  }
}

// ───────────────────── Widgets internes ─────────────────────

/// Bouton d’action avec halo animé (réutilisé pour Quiz & Modules).
class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final List<Color> glowColors;

  const _TopActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.glowColors,
  });

  @override
  Widget build(BuildContext context) {
    return RotatingGlowBorder(
      borderWidth: 2,
      colors: glowColors,
      duration: const Duration(seconds: 30),
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 18, color: glowColors.first),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: glowColors.first,
          ),
        ),
      ),
    );
  }
}

/// Bar personnalisée (gradient + flèches + boutons actions).
/// Barre haute compacte avec prise en compte de l’encoche
class _NavigationBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onGoQuiz;
  final VoidCallback onGoList;

  const _NavigationBar({
    required this.onBack,
    required this.onForward,
    required this.onGoQuiz,
    required this.onGoList,
  });

  // Hauteur de la zone interactive (hors encoche)
  static const double _barHeight = 60;

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top; // encoche / statut

    return Container(
      height: topInset + _barHeight,          // total = encoche + barre
      padding: EdgeInsets.only(top: topInset),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF73ABEC), Color(0xFF053191)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: onBack,
          ),
          const Spacer(),
          _TopActionButton(
            icon: Icons.play_arrow,
            label: 'Quiz'.tr(),
            onPressed: onGoQuiz,
            glowColors: [Colors.orange.shade800, Colors.deepOrange, Colors.orange],
          ),
          const SizedBox(width: 20),
          _TopActionButton(
            icon: Icons.list,
            label: 'Modules'.tr(),
            onPressed: onGoList,
            glowColors: [Colors.blue.shade800, Colors.blueAccent, Colors.blue.shade400],
          ),
          const SizedBox(width: 20),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: onForward,
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final ValueNotifier<int> current;
  final ValueNotifier<int> total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: current,
      builder: (context, page, _) => ValueListenableBuilder<int>(
        valueListenable: total,
        builder: (context, totalPages, __) {
          final progress = totalPages == 0 ? 0.0 : (page + 1) / totalPages;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LinearProgressIndicator(value: progress),
          );
        },
      ),
    );
  }
}

class _LessonContent extends StatefulWidget {
  final DocumentSnapshot lesson;
  final FlutterTts tts;
  const _LessonContent({required this.lesson, required this.tts});

  @override
  State<_LessonContent> createState() => _LessonContentState();
}

class _LessonContentState extends State<_LessonContent> {
  int? _playingIndex;

  @override
  void initState() {
    super.initState();
    widget.tts.setCompletionHandler(() {
      setState(() => _playingIndex = null);
    });
  }

  Future<void> _toggleSpeak(String text, int index) async {
    if (_playingIndex == index) {
      await widget.tts.stop();
      setState(() => _playingIndex = null);
    } else {
      await widget.tts.stop();
      await widget.tts.speak(text);
      setState(() => _playingIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.lesson.reference.collection('sections').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur de chargement'.tr()));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sections = snapshot.data?.docs ?? [];

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 24),
          itemBuilder: (context, index) {
            final section = sections[index];
            final html = section['content'] as String;
            final plainText = htmlToPlainText(html);

            final isPlaying = _playingIndex == index;

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bouton play/stop
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: isPlaying ? 'Stop' : 'Écouter',
                          icon: Icon(isPlaying ? Icons.stop : Icons.volume_up_rounded),
                          onPressed: () => _toggleSpeak(plainText, index),
                        ),
                      ],
                    ),
                    Html(
                      data: html,
                      style: {
                        'html': Style(fontSize: FontSize(17), lineHeight: LineHeight.number(1.6)),
                        'h1': Style(fontSize: FontSize(26), color: const Color(0xFF1E88E5)),
                        'h2': Style(fontSize: FontSize(22), color: const Color(0xFF1E88E5)),
                        'strong': Style(color: Colors.blue.shade800),
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
