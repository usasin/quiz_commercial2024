// invite_player_screen.dart
// ignore_for_file: use_build_context_synchronously

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

  // ───── Chapitres & niveaux
  List<QueryDocumentSnapshot<Map<String, dynamic>>> chapters = [];
  String? selectedChapterId;
  List<String> availableLevels = [];   // ex. ["Level 1", "Level 2", …]
  String? selectedLevelId;
  final PageController _chapterController =
  PageController(viewportFraction: .8);

  // ───── Recherche & sélection
  String search = '';
  final Map<String, String> _selectedPlayers = {}; // <uid , name>

  // ────────────────────────── INIT
  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  // ───────────────── FIREBASE HELPERS
  Future<void> _loadChapters() async {
    final snap = await FirebaseFirestore.instance
        .collection('chapters')
        .withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? {},
      toFirestore: (m, _) => m,
    )
        .get();

    chapters = snap.docs;
    if (chapters.isNotEmpty) _onChapterChanged(0);
    if (mounted) setState(() {});
  }

  Future<String> _getDownloadUrl(String gsUrl) async {
    if (gsUrl.trim().isEmpty) return '';
    try {
      return FirebaseStorage.instance.refFromURL(gsUrl).getDownloadURL();
    } catch (_) {
      return '';
    }
  }

  // ────────────────────────── NIVEAUX
  void _onChapterChanged(int idx) {
    final chap   = chapters[idx];
    final Map<String, dynamic> m = chap.data();

    // nombre total de niveaux : cherche numberOfLevels OU numberOfQuizzes
    final raw      = m['numberOfLevels'] ?? m['numberOfQuizzes'] ?? 1;
    final total    = (raw is int) ? raw : (raw as num).toInt();

    selectedChapterId = chap.id;
    availableLevels   = List.generate(total, (i) => 'Level ${i + 1}');
    selectedLevelId   = null;
    _selectedPlayers.clear();

    setState(() {});
  }

  // ────────────────────────── INVITATION
  Future<void> _invitePlayers() async {
    if (selectedChapterId == null ||
        selectedLevelId   == null ||
        _selectedPlayers.isEmpty) return;

    final me          = FirebaseAuth.instance.currentUser!;
    final challengeId = FirebaseFirestore.instance.collection('challenges').doc().id;

    // 1) document Challenge
    await FirebaseFirestore.instance
        .collection('challenges')
        .doc(challengeId)
        .set({
      'chapterId' : selectedChapterId,
      'levelId'   : selectedLevelId,
      'createdBy' : me.uid,
      'status'    : 'waiting',
      'players'   : {
        me.uid : {
          'name'     : me.displayName ?? 'Moi',
          'score'    : 0,
          'finished' : false,
          'photoURL' : me.photoURL ?? '',
        }
      },
      'createdAt' : FieldValue.serverTimestamp(),
    });

    // 2) invitations individuelles
    final invCol = FirebaseFirestore.instance.collection('invitations');
    final batch  = FirebaseFirestore.instance.batch();

    _selectedPlayers.forEach((uid, name) {
      batch.set(invCol.doc(), {
        'senderId'      : me.uid,
        'recipientId'   : uid,
        'recipientName' : name,
        'challengeId'   : challengeId,
        'chapterId'     : selectedChapterId,
        'levelId'       : selectedLevelId,
        'status'        : 'pending',
        'createdAt'     : FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();

    // 3) → Lobby
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeLobby(
          isCreator  : true,
          challengeId: challengeId,
          chapterId  : selectedChapterId!,
          levelId    : selectedLevelId!,
        ),
      ),
    );
  }

  // ────────────────────────── UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex : 3,
        scaffoldKey  : GlobalKey(),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.deepPurple.shade300, Colors.indigo.shade700],
            begin : Alignment.topCenter,
            end   : Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(
                child: GradientText(
                  'Inviter plusieurs joueurs',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade100, Colors.deepPurple.shade300, Colors.indigo.shade700],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ───── Carousel chapitres
              if (chapters.isEmpty)
                const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
              else
                SizedBox(
                  height: 180,
                  child: PageView.builder(
                    controller   : _chapterController,
                    onPageChanged: _onChapterChanged,
                    itemCount    : chapters.length,
                    itemBuilder  : (_, i) {
                      final Map<String, dynamic> m = chapters[i].data();
                      final title = m['title']    as String? ?? 'Chapitre';
                      final gsUrl = m['imageUrl'] as String? ?? '';

                      return FutureBuilder<String>(
                        future: _getDownloadUrl(gsUrl),
                        builder: (_, snap) {
                          final urlReady = snap.connectionState == ConnectionState.done && snap.data!.isNotEmpty;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            shape : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (urlReady)
                                  Image.network(snap.data!, fit: BoxFit.cover)
                                else
                                  const Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.black45, Colors.transparent],
                                      begin : Alignment.bottomCenter,
                                      end   : Alignment.topCenter,
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(title,
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),

              // ───── Choix de niveaux
              if (selectedChapterId != null)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: availableLevels.map((lvl) {
                      final selected = lvl == selectedLevelId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(lvl, style: TextStyle(color: selected ? Colors.white : Colors.black87)),
                          selected     : selected,
                          onSelected   : (_) => setState(() => selectedLevelId = lvl),
                          selectedColor: Colors.deepPurple,
                          backgroundColor: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 16),

              // ───── Zone de recherche
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    label: GradientText(
                      'Rechercher un joueur',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      gradient: const LinearGradient(colors: [Colors.white70, Colors.white]),
                    ),
                    filled: true,
                    fillColor: Colors.white24,
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
                ),
              ),

              const SizedBox(height: 8),

              // ───── Liste joueurs filtrée
              if (selectedChapterId != null && selectedLevelId != null)
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('name_lower', isGreaterThanOrEqualTo: search)
                        .where('name_lower', isLessThanOrEqualTo: '$search\uf8ff')
                        .snapshots(),
                    builder: (_, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs.where((d) => d.id != currentUid).toList();
                      if (docs.isEmpty) {
                        return const Center(child: Text('Aucun joueur trouvé.', style: TextStyle(color: Colors.white)));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final Map<String, dynamic> data = docs[i].data();
                          final uid   = docs[i].id;
                          final name  = data['name']     as String? ?? 'Inconnu';
                          final photo = data['photoURL'] as String? ?? '';

                          final selected = _selectedPlayers.containsKey(uid);

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: selected ? Colors.deepPurple.shade50 : Colors.white.withOpacity(.9),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundImage: photo.startsWith('http') ? NetworkImage(photo) : null,
                                backgroundColor: photo.isEmpty ? Colors.grey.shade400 : null,
                                child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: IconButton(
                                icon: Icon(selected ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: selected ? Colors.deepPurple : Colors.grey),
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
                  ),
                ),

              // ───── Bouton « Inviter »
              if (_selectedPlayers.isNotEmpty)
                RotatingGlowBorder(
                  borderWidth: 3,
                  borderRadius: 6,
                  colors: [Colors.deepPurpleAccent, Colors.white, Colors.deepPurpleAccent],
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
