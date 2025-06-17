import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../rotating_glow_border.dart';
import '../gradient_text.dart';  // <-- nouveau

class ChapterMenuPage extends StatefulWidget {
  @override
  _ChapterMenuPageState createState() => _ChapterMenuPageState();
}

class _ChapterMenuPageState extends State<ChapterMenuPage> {
  final ScrollController _scrollController = ScrollController();
  double _savedScrollPosition = 0.0;
  String lastPlayedChapterId = "";
  Map<String, int> chapterScores = {};
  Map<String, int> unlockedLevels = {};
  Map<String, int> unlockedModules = {};

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadScrollPosition();
  }

  void _loadScrollPosition() async {
    setState(() => _savedScrollPosition = 0.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_savedScrollPosition);
      }
    });
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return;
    final data = userDoc.data()!;
    setState(() {
      lastPlayedChapterId = data['lastChapterId'] ?? "";
      if (data['chapters'] is Map) {
        (data['chapters'] as Map).forEach((k, v) {
          if (v is Map && v['totalScore'] is int) chapterScores[k] = v['totalScore'];
        });
      }
      if (data['unlockedLevels'] is Map) unlockedLevels = Map<String,int>.from(data['unlockedLevels']);
      if (data['unlockedModules'] is Map) unlockedModules = Map<String,int>.from(data['unlockedModules']);
    });
  }

  Future<String> _getImageUrl(String gsUrl) async {
    return await FirebaseStorage.instance.refFromURL(gsUrl).getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Image.asset('assets/images/backgroundlogin.jpg', fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0,5))],
              ),
              child: Column(
                children: [
                  // —— TITRE AVEC GRADIENT ——
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: GradientText(
                      "Choisir parcours".tr(),
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade800, Colors.blue.shade400],
                      ),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // —— LISTE DES CHAPITRES ——
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('chapters').snapshots(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) return Center(child: CircularProgressIndicator());
                        final docs = snap.data!.docs;
                        final featured = docs.where((d) => d.id == "chapter5").toList();
                        final others   = docs.where((d) => d.id != "chapter5").toList()
                          ..sort((a,b) => (chapterScores[b.id] ?? 0).compareTo(chapterScores[a.id] ?? 0));
                        return SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (featured.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical:10,horizontal:15),
                                  child: GradientText(
                                    "Départ – Script Standard".tr(),
                                    gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.amber.shade200]),
                                    style: TextStyle(fontSize:20,fontWeight:FontWeight.bold),
                                  ),
                                ),
                                ...featured.map(_buildChapterCard),
                              ],
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical:10,horizontal:15),
                                child: GradientText(
                                  "Autres Formats de Vente".tr(),
                                  gradient: LinearGradient(colors: [Colors.blue.shade600, Colors.cyan.shade200]),
                                  style: TextStyle(fontSize:20,fontWeight:FontWeight.bold),
                                ),
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: others.length,
                                itemBuilder: (_,i) => _buildChapterCard(others[i]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(QueryDocumentSnapshot chapter) {
    final isLast = chapter.id == lastPlayedChapterId;
    final score = chapterScores[chapter.id] ?? 0;
    final quizzes = chapter['numberOfQuizzes'] as int;
    final levels = (unlockedLevels[chapter.id] ?? 1) - 1;
    final lvDone = levels.clamp(0, quizzes);
    final lvProg = quizzes>0 ? (lvDone/quizzes).clamp(0.0,1.0) : 0.0;
    final mods = chapter['numberOfModules'] as int? ?? 0;
    final mdDone = unlockedModules[chapter.id] ?? 1;
    final mdProg = mods>0 ? (mdDone/mods).clamp(0.0,1.0) : 1.0;
    final completed = lvDone>=quizzes && mdDone>=mods;

    Widget card = AnimatedContainer(
      duration: Duration(milliseconds:500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLast
              ? [Colors.amber.shade50, Colors.amber.shade100]
              : completed
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isLast
              ? Colors.amber.shade800
              : completed
              ? Colors.green.shade800
              : Colors.transparent,
          width: isLast||completed?2:0,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color:Colors.black26,blurRadius:10,offset:Offset(0,5))],
      ),
      padding: EdgeInsets.all(15),
      child: InkWell(
        onTap: () => _onChapterTap(chapter),
        child: Row(
          children: [
            FutureBuilder<String>(
              future: _getImageUrl(chapter['imageUrl']),
              builder: (ctx,s) {
                if (s.connectionState==ConnectionState.waiting)
                  return SizedBox(width:80,height:80,child:Center(child:CircularProgressIndicator()));
                if (s.hasError||!s.hasData)
                  return Icon(Icons.broken_image,size:60,color:Colors.grey);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(s.data!,width:110,height:80,fit:BoxFit.cover),
                );
              },
            ),
            SizedBox(width:15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GradientText(
                    chapter['title'].toString().tr(),
                    gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade400]),
                    style: TextStyle(fontSize:16,fontWeight:FontWeight.bold),
                  ),
                  SizedBox(height:5),
                  Text("Score : $score", style: TextStyle(color:Colors.grey.shade700)),
                  Text("Niveaux : $lvDone / $quizzes", style: TextStyle(color:Colors.blueGrey.shade700)),
                  LinearProgressIndicator(value: lvProg, backgroundColor:Colors.grey.shade200, valueColor:AlwaysStoppedAnimation(completed?Colors.green:Colors.blue)),
                  if (mods>0) ...[
                    SizedBox(height:8),
                    Text("Modules : $mdDone / $mods", style: TextStyle(color:Colors.blueGrey.shade700)),
                    LinearProgressIndicator(value: mdProg, backgroundColor:Colors.grey.shade200, valueColor:AlwaysStoppedAnimation(mdDone>=mods?Colors.green:Colors.blue.shade800)),
                  ],
                  SizedBox(height:8),
                  if (isLast)
                    Text("⭐ Dernier joué".tr(), style: TextStyle(color:Colors.amber.shade800,fontWeight:FontWeight.w600)),
                  if (completed)
                    Text("✅ Terminé".tr(), style: TextStyle(color:Colors.green.shade800,fontWeight:FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isLast) {
      card = RotatingGlowBorder(
        borderWidth: 4,
        colors: [Colors.blue.shade800, Colors.blueAccent, Colors.blue.shade500],
        duration: Duration(seconds:2),
        child: card,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical:10,horizontal:15),
      child: card,
    );
  }

  void _onChapterTap(QueryDocumentSnapshot chapter) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final map = doc.data() as Map<String,dynamic>? ?? {};
    final pos = (map['scrollPositions']?[chapter.id] as num?)?.toDouble() ?? 0.0;
    Navigator.pushNamed(context, '/levels', arguments:{ 'chapterId':chapter.id, 'scrollPosition':pos, 'fromMenu'      : true, });
  }
}
