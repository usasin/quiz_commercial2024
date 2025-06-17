// challenge_lobby.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../drawer/custom_bottom_nav_bar.dart';
import '../gradient_text.dart';
import '../services/challenge_service.dart';
import '../models/challenge_model.dart';

import 'challenge_quiz.dart';
import 'invite_player_screen.dart';
import '../rotating_glow_border.dart';

class ChallengeLobby extends StatefulWidget {
  final bool isCreator;
  final bool isSolo;
  final String? challengeId;
  final String levelId;
  final String chapterId;

  const ChallengeLobby({
    Key? key,
    required this.isCreator,
    this.isSolo = false,
    this.challengeId,
    required this.levelId,
    required this.chapterId,
  }) : super(key: key);

  @override
  _ChallengeLobbyState createState() => _ChallengeLobbyState();
}

class _ChallengeLobbyState extends State<ChallengeLobby> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ChallengeService _service = ChallengeService();
  String? _challengeId;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _init();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final me = FirebaseAuth.instance.currentUser!;
    if (widget.isCreator) {
      _challengeId = widget.challengeId;
    } else {
      await _service.joinChallenge(
        challengeId: widget.challengeId!,
        uid: me.uid,
        name: me.displayName ?? 'Joueur',
      );
      _challengeId = widget.challengeId;
    }
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (_challengeId != null) {
      await _service.startChallenge(_challengeId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_challengeId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<ChallengeModel>(
      stream: _service.listenToChallenge(_challengeId!),
      builder: (ctx, snapCh) {
        if (!snapCh.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final challenge = snapCh.data!;
        if (challenge.status == 'started') {
          return ChallengeQuizScreen(challenge: challenge);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('invitations')
              .where('challengeId', isEqualTo: _challengeId)
              .snapshots(),
          builder: (ctx2, snapInv) {
            if (!snapInv.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final invites = snapInv.data!.docs;
            final pending = invites
                .where((d) => (d.data() as Map<String, dynamic>)['status'] == 'pending')
                .toList();
            final declined = invites
                .where((d) => (d.data() as Map<String, dynamic>)['status'] == 'declined')
                .toList();
            final players = challenge.players.values.toList();
            // prêt si le créateur + au moins 1 autre (length>=2), ou en solo
            final ready = widget.isSolo || players.length >= 2;

            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton(
                backgroundColor: Colors.deepPurple,
                tooltip: 'Retour',
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const InvitePlayerScreen()),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
              bottomNavigationBar: CustomBottomNavBar(
                parentContext: context,
                currentIndex: 3,
                scaffoldKey: _scaffoldKey,
              ),
              body: Column(
                children: [
                  const SizedBox(height: 40),
                  GradientText(
                    '👥 Salle de défi',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurpleAccent, Colors.white],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Lottie quand aucun autre joueur n'est encore accepté
                  if (!widget.isSolo && players.isEmpty)
                    SizedBox(
                      height: 180,
                      child: Lottie.asset(
                        'assets/animations/salle de defi.json',
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),

                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        // En attente
                        ...pending.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['recipientName'] as String? ?? 'Joueur';
                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.grey),
                            title: Text(name, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            subtitle: const Text('En attente…', style: TextStyle(color: Colors.grey)),
                          );
                        }),
                        // Refusé
                        ...declined.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['recipientName'] as String? ?? 'Joueur';
                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.grey),
                            title: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            subtitle: const Text('Refusé', style: TextStyle(color: Colors.grey)),
                          );
                        }),
                        // Acceptés
                        ...players.map((p) {
                          return RotatingGlowBorder(
                            borderWidth: 3,
                            borderRadius: 12,
                            colors: [Colors.deepPurpleAccent, Colors.white, Colors.deepPurpleAccent],
                            duration: const Duration(seconds: 5),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundImage: p.photoURL != null
                                        ? NetworkImage(p.photoURL!)
                                        : const AssetImage('assets/images/user.png') as ImageProvider,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bouton Commencer activé seulement si ready == true
                  if (widget.isCreator && ready)
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Commencer le défi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _start,
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
