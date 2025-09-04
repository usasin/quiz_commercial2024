// lib/screens/invite_player_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../drawer/custom_bottom_nav_bar.dart';
import '../gradient_text.dart';
import '../rotating_glow_border.dart';
import 'challenge_lobby.dart';

enum InviteMode { ai, users }

class InvitePlayerScreen extends StatefulWidget {
  const InvitePlayerScreen({Key? key}) : super(key: key);

  @override
  State<InvitePlayerScreen> createState() => _InvitePlayerScreenState();
}

class _InvitePlayerScreenState extends State<InvitePlayerScreen> {
  InviteMode _mode = InviteMode.users;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // Chapitres
  List<QueryDocumentSnapshot<Map<String, dynamic>>> chapters = [];
  String? selectedChapterId;
  late final PageController _chapterController;

  // Recherche & sélection
  String search = '';
  final Map<String, String> _selectedPlayers = {};

  @override
  void initState() {
    super.initState();
    _chapterController = PageController(viewportFraction: 0.8);
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    final snap = await FirebaseFirestore.instance
        .collection('chapters_challenge')
        .withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? {},
      toFirestore: (m, _) => m,
    )
        .get();
    chapters = snap.docs;
    if (chapters.isNotEmpty) _onChapterChanged(0);
    setState(() {});
  }

  Future<String> _getDownloadUrl(String gsUrl) async {
    if (gsUrl.trim().isEmpty) return '';
    try {
      return await FirebaseStorage.instance.refFromURL(gsUrl).getDownloadURL();
    } catch (_) {
      return '';
    }
  }

  void _onChapterChanged(int idx) {
    selectedChapterId = chapters[idx].id;
    _selectedPlayers.clear();
    setState(() {});
  }

  Future<void> _startSoloChallenge() async {
    if (selectedChapterId == null) return;
    final me = FirebaseAuth.instance.currentUser!;
    final challengeId =
        FirebaseFirestore.instance.collection('challenges').doc().id;

    // Crée et démarre immédiatement en solo
    await FirebaseFirestore.instance.collection('challenges').doc(challengeId).set({
      'chapterId': selectedChapterId,
      'levelId': 'random',
      'createdBy': me.uid,
      'status': 'started',
      'isSolo': true,
      'players': {
        me.uid: {
          'name': me.displayName ?? 'Moi',
          'score': 0,
          'finished': false,
          'photoURL': me.photoURL ?? '',
        },
        'IA': {
          'name': 'IA',
          'score': 0,
          'finished': false,
          'photoURL': '',
        },
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeLobby(
          isCreator: true,
          isSolo: true,
          challengeId: challengeId,
          chapterId: selectedChapterId!,
          levelId: 'random',
        ),
      ),
    );
  }

  Future<void> _invitePlayers() async {
    if (selectedChapterId == null || _selectedPlayers.isEmpty) return;
    final me = FirebaseAuth.instance.currentUser!;
    final challengeId =
        FirebaseFirestore.instance.collection('challenges').doc().id;

    // 1) crée le challenge en attente
    await FirebaseFirestore.instance.collection('challenges').doc(challengeId).set({
      'chapterId': selectedChapterId,
      'levelId': 'random',
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

    // 2) invitations en batch
    final invCol = FirebaseFirestore.instance.collection('invitations');
    final batch = FirebaseFirestore.instance.batch();
    _selectedPlayers.forEach((uid, name) {
      batch.set(invCol.doc(), {
        'senderId': me.uid,
        'recipientId': uid,
        'recipientName': name,
        'challengeId': challengeId,
        'chapterId': selectedChapterId,
        'levelId': 'random',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();

    // 3) vers le lobby
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeLobby(
          isCreator: true,
          challengeId: challengeId,
          chapterId: selectedChapterId!,
          levelId: 'random',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 3,
        scaffoldKey: GlobalKey(),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.indigo.shade700,
              Colors.deepPurple.shade300,
              Colors.indigo.shade700,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── TITRE
              GradientText(
                'Inviter un défi',
                style: TextStyle(
                    fontSize: size.width * 0.08, fontWeight: FontWeight.bold),
                gradient: LinearGradient(
                  colors: [
                    Colors.indigo.shade100,
                    Colors.deepPurple.shade300,
                    Colors.indigo.shade700,
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── CAROUSEL CHAPITRES
              if (chapters.isEmpty)
                const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SizedBox(
                  height: 180,
                  child: PageView.builder(
                    controller: _chapterController,
                    onPageChanged: _onChapterChanged,
                    itemCount: chapters.length,
                    itemBuilder: (_, i) {
                      final m = chapters[i].data();
                      final title = m['title'] as String? ?? 'Chapitre';
                      final gsUrl = m['imageUrl'] as String? ?? '';
                      return FutureBuilder<String>(
                        future: _getDownloadUrl(gsUrl),
                        builder: (_, snap) {
                          final urlReady = snap.connectionState == ConnectionState.done &&
                              snap.data!.isNotEmpty;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (urlReady)
                                  Image.network(snap.data!, fit: BoxFit.cover)
                                else
                                  const Icon(Icons.image_not_supported,
                                      size: 60, color: Colors.grey),
                                Container(
                                  decoration: const BoxDecoration(
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
                                          fontWeight: FontWeight.bold),
                                    ),
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

              // ── CHOIX DE MODE
              // ── CHOIX DE MODE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _mode = InviteMode.ai),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // fond blanc toujours
                          side: BorderSide(
                            color: _mode == InviteMode.ai
                                ? Colors.indigo.shade700  // bordure indigo si sélectionné
                                : Colors.grey.shade300,    // bordure grise sinon
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: GradientText(
                          'Contre l’IA',
                          style: TextStyle(
                            fontSize: size.width * 0.055,
                            fontWeight: FontWeight.bold,
                            // on force la couleur blanche ici : GradientText la remplace
                            color: Colors.white,
                          ),
                          gradient: _mode == InviteMode.ai
                              ? LinearGradient(              // dégradé coloré si sélectionné
                            colors: [Colors.indigo, Colors.blueAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : LinearGradient(              // dégradé gris si non-sélectionné
                            colors: [Colors.grey.shade600, Colors.grey.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _mode = InviteMode.users),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _mode == InviteMode.users
                                ? Colors.deepPurpleAccent
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: GradientText(
                          'Multijoueurs',
                          style: TextStyle(
                            fontSize: size.width * 0.050,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          gradient: _mode == InviteMode.users
                              ? LinearGradient(
                            colors: [Colors.deepPurple, Colors.purpleAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : LinearGradient(
                            colors: [Colors.grey.shade600, Colors.grey.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),



              const SizedBox(height: 16),
              Expanded(
                child: _mode == InviteMode.ai
                // Mode IA : bouton centré avec halo animé
                    ? Center(
                  child: RotatingGlowBorder(
                    borderWidth: 3,
                    borderRadius: 12,
                    colors: const [
                      Colors.indigoAccent,
                      Colors.purpleAccent,
                      Colors.indigoAccent,
                    ],
                    duration: const Duration(seconds: 3),
                    child: ElevatedButton(
                      onPressed: _startSoloChallenge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0, // on laisse le halo faire l’effet
                      ),
                      child: GradientText(
                        'Commencer contre l’IA',
                        style: TextStyle(
                          fontSize: size.width * 0.05,
                          fontWeight: FontWeight.bold,
                        ),
                        gradient: const LinearGradient(
                          colors: [Colors.indigoAccent, Colors.purpleAccent],
                        ),
                      ),
                    ),
                  ),
                )
                // Mode Joueurs : recherche + liste
                    : Column(
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: InputDecoration(
                          label: GradientText(
                            'Rechercher un joueur',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            gradient: const LinearGradient(
                                colors: [Colors.white70, Colors.white]),
                          ),
                          filled: true,
                          fillColor: Colors.white24,
                          prefixIcon: const Icon(Icons.search,
                              color: Colors.white),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (v) =>
                            setState(() => search = v.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('name_lower',
                            isGreaterThanOrEqualTo: search)
                            .where('name_lower',
                            isLessThanOrEqualTo: '$search\uf8ff')
                            .snapshots(),
                        builder: (_, snap) {
                          if (!snap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final docs = snap.data!.docs
                              .where((d) => d.id != currentUid)
                              .toList();
                          if (docs.isEmpty) {
                            return const Center(
                                child: Text(
                                    'Aucun joueur trouvé.',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16)));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final data = docs[i].data();
                              final uid = docs[i].id;
                              final name =
                                  data['name'] as String? ?? 'Inconnu';
                              final photo =
                                  data['photoURL'] as String? ?? '';
                              final selected =
                              _selectedPlayers.containsKey(uid);
                              return Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12)),
                                color: selected
                                    ? Colors.deepPurple.shade50
                                    : Colors.white.withOpacity(.9),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundImage: photo
                                        .startsWith('http')
                                        ? NetworkImage(photo)
                                        : null,
                                    backgroundColor: photo.isEmpty
                                        ? Colors.grey.shade400
                                        : null,
                                    child: photo.isEmpty
                                        ? const Icon(Icons.person,
                                        color: Colors.white)
                                        : null,
                                  ),
                                  title: Text(name,
                                      style: const TextStyle(
                                          fontWeight:
                                          FontWeight.bold)),
                                  trailing: IconButton(
                                    icon: Icon(
                                      selected
                                          ? Icons.check_box
                                          : Icons
                                          .check_box_outline_blank,
                                      color: selected
                                          ? Colors.deepPurple
                                          : Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (selected) {
                                          _selectedPlayers.remove(uid);
                                        } else {
                                          _selectedPlayers[uid] = name;
                                        }
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
                  ],
                ),
              ),

              // ── BOUTON INVITER (mode Joueurs + au moins 1 sélectionné)
              if (_mode == InviteMode.users && _selectedPlayers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: RotatingGlowBorder(
                    borderWidth: 3,
                    borderRadius: 6,
                    colors: [
                      Colors.deepPurpleAccent,
                      Colors.white,
                      Colors.deepPurpleAccent
                    ],
                    duration: const Duration(seconds: 3),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _invitePlayers,
                        icon: const Icon(Icons.person_add),
                        label: Text(
                            'Inviter ${_selectedPlayers.length} joueur(s)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
