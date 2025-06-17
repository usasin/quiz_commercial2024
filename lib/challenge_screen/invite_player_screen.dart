// invite_player_screen.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../drawer/custom_bottom_nav_bar.dart';
import '../gradient_text.dart';
import '../rotating_glow_border.dart';
import 'challenge_lobby.dart';

class InvitePlayerScreen extends StatefulWidget {
  const InvitePlayerScreen({Key? key}) : super(key: key);

  @override
  State<InvitePlayerScreen> createState() => _InvitePlayerScreenState();
}

class _InvitePlayerScreenState extends State<InvitePlayerScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // Chapitres & niveaux
  List<QueryDocumentSnapshot> chapters = [];
  Map<String, int> unlockedLevels = {};
  String? selectedChapterId;
  List<String> availableLevels = [];
  String? selectedLevelId;
  final PageController _chapterController = PageController(viewportFraction: 0.8);

  // Recherche & sélection multiple
  String search = '';
  final Map<String, String> _selectedPlayers = {};

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadChapters();
  }

  Future<void> _loadUser() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
    unlockedLevels = Map<String, int>.from(doc.data()?['unlockedLevels'] ?? {});
    setState(() {});
  }

  Future<void> _loadChapters() async {
    final snap = await FirebaseFirestore.instance.collection('chapters').get();
    chapters = snap.docs;
    if (chapters.isNotEmpty) _onChapterChanged(0);
    setState(() {});
  }

  Future<String> _getDownloadUrl(String gsUrl) =>
      FirebaseStorage.instance.refFromURL(gsUrl).getDownloadURL();

  void _onChapterChanged(int idx) {
    final chap = chapters[idx];
    selectedChapterId = chap.id;
    final maxLvl = unlockedLevels[chap.id] ?? 0;
    availableLevels = List.generate(maxLvl, (i) => 'Level ${i + 1}');
    selectedLevelId = null;
    _selectedPlayers.clear();
    setState(() {});
  }

  Future<bool> _isLevelUnlocked(String uid, String chapId, String lvl) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final otherMap = Map<String, dynamic>.from(doc.data()?['unlockedLevels'] ?? {});
    final otherMax = otherMap[chapId] as int? ?? 0;
    final lvlNum = int.tryParse(lvl.split(' ').last) ?? 0;
    return otherMax >= lvlNum;
  }

  Future<void> _invitePlayers() async {
    if (selectedChapterId == null || selectedLevelId == null || _selectedPlayers.isEmpty) return;
    final me = FirebaseAuth.instance.currentUser!;
    final challengeRef = FirebaseFirestore.instance.collection('challenges').doc();
    await challengeRef.set({
      'chapterId': selectedChapterId,
      'levelId': selectedLevelId,
      'createdBy': me.uid,
      'status': 'waiting',
      'players': {
        me.uid: {
          'name': me.displayName ?? 'Moi',
          'score': 0,
          'finished': false,
          'photoURL': me.photoURL ?? '',
        }
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    final batch = FirebaseFirestore.instance.batch();
    final invCol = FirebaseFirestore.instance.collection('invitations');
    _selectedPlayers.forEach((uid, name) {
      final doc = invCol.doc();
      batch.set(doc, {
        'senderId': me.uid,
        'recipientId': uid,
        'recipientName': name,
        'challengeId': challengeRef.id,
        'chapterId': selectedChapterId,
        'levelId': selectedLevelId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ChallengeLobby(
        isCreator: true,
        challengeId: challengeRef.id,
        chapterId: selectedChapterId!,
        levelId: selectedLevelId!,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 3,
        scaffoldKey: GlobalKey(),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.deepPurple.shade300, Colors.indigo.shade700],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(
                child: GradientText(
                  'Inviter plusieurs joueurs',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade100, Colors.deepPurple.shade300, Colors.indigo.shade700],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Carousel Chapitres
              if (chapters.isEmpty)
                const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
              else
                SizedBox(
                  height: 180,
                  child: PageView.builder(
                    controller: _chapterController,
                    onPageChanged: _onChapterChanged,
                    itemCount: chapters.length,
                    itemBuilder: (ctx, i) {
                      final doc = chapters[i];
                      final title = doc['title'] as String;
                      final gsUrl = doc['imageUrl'] as String;
                      final unlocked = unlockedLevels.containsKey(doc.id);
                      return Opacity(
                        opacity: unlocked ? 1 : 0.4,
                        child: FutureBuilder<String>(
                          future: _getDownloadUrl(gsUrl),
                          builder: (ctx2, snap) {
                            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              clipBehavior: Clip.hardEdge,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(snap.data!, fit: BoxFit.cover),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.black45, Colors.transparent],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),

              // Choix de niveaux
              if (selectedChapterId != null)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: availableLevels.map((lvl) {
                      final isSelected = lvl == selectedLevelId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(lvl, style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
                          selected: isSelected,
                          onSelected: (_) => setState(() => selectedLevelId = lvl),
                          selectedColor: Colors.deepPurple,
                          backgroundColor: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 16),

              // Recherche joueurs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    // on remplace hintText par label
                    label: GradientText(
                      'Rechercher un joueur',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      gradient: const LinearGradient(
                        colors: [Colors.white70, Colors.white],
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white24,
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(() => search = v.toLowerCase()),
                ),
              ),

              const SizedBox(height: 8),

              // Liste avec sélection multiple
              if (selectedChapterId != null && selectedLevelId != null)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('name_lower', isGreaterThanOrEqualTo: search)
                        .where('name_lower', isLessThanOrEqualTo: '$search\uf8ff')
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snap.data!.docs.where((d) => d.id != currentUid).toList();
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('Aucun joueur trouvé.', style: TextStyle(color: Colors.white)),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (ctx, i) {
                          final d = docs[i];
                          final data = d.data() as Map<String, dynamic>;
                          final uid = d.id;
                          final name = data['name'] as String? ?? 'Inconnu';
                          final photo = data['photoURL'] as String? ?? '';
                          return FutureBuilder<bool>(
                            future: _isLevelUnlocked(uid, selectedChapterId!, selectedLevelId!),
                            builder: (ctx2, uSnap) {
                              if (!uSnap.hasData || !uSnap.data!) return const SizedBox();
                              final selected = _selectedPlayers.containsKey(uid);
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                color: selected ? Colors.deepPurple.shade50 : Colors.white.withOpacity(0.9),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundImage: photo.startsWith('http') ? NetworkImage(photo) : null,
                                    backgroundColor: photo.isEmpty ? Colors.grey.shade400 : null,
                                    child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                                  ),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: IconButton(
                                    icon: Icon(
                                      selected ? Icons.check_box : Icons.check_box_outline_blank,
                                      color: selected ? Colors.deepPurple : Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (selected) _selectedPlayers.remove(uid);
                                        else _selectedPlayers[uid] = name;
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

              // Bouton Inviter multiple
              if (_selectedPlayers.isNotEmpty)
              /// … dans votre build() là où vous aviez le Padding // SizedBox // ElevatedButton…
                RotatingGlowBorder(
                  borderWidth: 3,
                  borderRadius: 5,
                  colors: [
                    Colors.deepPurpleAccent,
                    Colors.white,
                    Colors.deepPurpleAccent,
                  ],
                  duration: const Duration(seconds: 3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _invitePlayers,
                        icon: const Icon(Icons.person_add),
                        label: Text('Inviter ${_selectedPlayers.length} joueur(s)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }
}
