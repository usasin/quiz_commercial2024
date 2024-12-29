import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../drawer/custom_bottom_nav_bar.dart';
import 'levels_page.dart';
import 'lessons_screen.dart';

class ModulePage extends StatefulWidget {
  final String moduleId;
  final int parcoursNumber;
  final String chapterId;

  ModulePage({
    required this.moduleId,
    required this.chapterId,
    required this.parcoursNumber,
  });

  @override
  _ModulePageState createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> {
  late PageController _pageController;
  ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  ValueNotifier<int> _totalPagesNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController()
      ..addListener(() {
        if (_pageController.hasClients && _pageController.page != null) {
          _currentPage.value = _pageController.page!.round();
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.grey.shade200,
            Colors.white,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const SizedBox(height: 50),
            // Barre flottante pour naviguer entre les pages
            _buildNavigationBar(),
            // Barre de progression (indicateurs de page)
            _buildProgressBar(),
            // Contenu principal avec défilement des pages
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('lessons')
                    .doc(widget.moduleId)
                    .collection('lessons')
                    .orderBy('lessonNumber')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Une erreur s\'est produite'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final lessons = snapshot.data?.docs ?? [];
                  _totalPagesNotifier.value = lessons.length;

                  return PageView.builder(
                    controller: _pageController,
                    itemCount: lessons.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot lesson = lessons[index];
                      return _buildLessonContent(lesson);
                    },
                  );
                },
              ),
            ),
            // Deux boutons fixes en bas
            _buildBottomButtons(context),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(
          parentContext: context,
          currentIndex: 0,
          scaffoldKey: GlobalKey<ScaffoldState>(),
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.orange,
            Colors.blue,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FloatingActionButton(
            heroTag: "leftButton",
            mini: true,
            backgroundColor: Colors.blue.shade800,
            child: const Icon(Icons.chevron_left, size: 24),
            onPressed: () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            },
          ),
          FloatingActionButton(
            heroTag: "rightButton",
            mini: true,
            backgroundColor: Colors.blue.shade800,
            child: const Icon(Icons.chevron_right, size: 24),
            onPressed: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return ValueListenableBuilder<int>(
      valueListenable: _currentPage,
      builder: (context, value, child) {
        return ValueListenableBuilder<int>(
          valueListenable: _totalPagesNotifier,
          builder: (context, totalPages, child) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  totalPages > 0 ? totalPages : 3, // Affiche 3 points par défaut
                      (index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.0),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value == index
                          ? Colors.blue.shade800
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLessonContent(DocumentSnapshot lesson) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: lesson.reference.collection('sections').snapshots(),
          builder: (context, sectionSnapshot) {
            if (sectionSnapshot.hasError) {
              return const Center(child: Text('Erreur de chargement'));
            }
            if (sectionSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final sections = sectionSnapshot.data?.docs ?? [];
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                DocumentSnapshot section = sections[index];
                return Html(
                  data: section['content'],
                  style: {
                    "html": Style(
                      fontSize: FontSize(18),
                      color: Color(0xFF000000),
                      lineHeight: LineHeight.number(1.5),
                    ),
                    "h1": Style(fontSize: FontSize(24.0), color: Colors.lightGreen),
                    "h2": Style(fontSize: FontSize(18.0), color: Colors.orange),
                    "strong": Style(
                      fontSize: FontSize(16.0), color: Colors.blue.shade800,
                    ),
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LevelsPage()),
                );
              },
              icon: Icon(Icons.play_arrow),
              label: Text("Continuer vers le Quiz"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LessonsScreen()),
                );
              },
              icon: Icon(Icons.list),
              label: Text("Listes Modules"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
