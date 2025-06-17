// challenge_home_menu.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'invite_player_screen.dart';
import 'challenge_lobby.dart';
import '../drawer/custom_bottom_nav_bar.dart';

class ChallengeHomeMenu extends StatefulWidget {
  const ChallengeHomeMenu({Key? key}) : super(key: key);

  @override
  _ChallengeHomeMenuState createState() => _ChallengeHomeMenuState();
}

class _ChallengeHomeMenuState extends State<ChallengeHomeMenu> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<QuerySnapshot>? _inviteSub;
  final Set<String> _shownInvites = {};

  @override
  void initState() {
    super.initState();
    _listenInvitations();
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    super.dispose();
  }

  /// Écoute en temps réel la collection "invitations" pour ce user
  void _listenInvitations() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _inviteSub = FirebaseFirestore.instance
        .collection('invitations')
        .where('recipientId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          if (_shownInvites.contains(doc.id)) continue;
          _shownInvites.add(doc.id);

          final data = doc.data() as Map<String, dynamic>;
          _showInviteDialog(
            inviteId: doc.id,
            challengeId: data['challengeId'] as String,
            levelId: data['levelId'] as String,
            chapterId: data['chapterId'] as String,
          );
        }
      }
    });
  }

  /// Affiche le dialogue d’invitation avec Accept/Decline
  void _showInviteDialog({
    required String inviteId,
    required String challengeId,
    required String levelId,
    required String chapterId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitation reçue !'),
        content: const Text('Vous avez été invité(e) à rejoindre un défi.'),
        actions: [
          TextButton(
            onPressed: () {
              // Mettre à jour l’invitation en "declined"
              FirebaseFirestore.instance
                  .collection('invitations')
                  .doc(inviteId)
                  .update({'status': 'declined'});
              Navigator.of(ctx).pop();
            },
            child: const Text('Refuser'),
          ),
          ElevatedButton(
            onPressed: () {
              // Accepter : passe en "accepted" et on ouvre le lobby
              FirebaseFirestore.instance
                  .collection('invitations')
                  .doc(inviteId)
                  .update({'status': 'accepted'});
              Navigator.of(ctx).pop();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChallengeLobby(
                    isCreator: false,
                    challengeId: challengeId,
                    levelId: levelId,
                    chapterId: chapterId,
                  ),
                ),
              );
            },
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          Image.asset(
            'assets/images/backgroundlogin.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Défi en ligne',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildBigButton(
                    context,
                    icon: Icons.person_add,
                    label: 'Inviter un joueur',
                    color: Colors.indigo,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InvitePlayerScreen()),
                    ),
                  ),
                  // Le bouton "Mes défis reçus" et "Rejoindre avec un code" ont été supprimés
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 3,
        scaffoldKey: _scaffoldKey,
      ),
    );
  }

  Widget _buildBigButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }
}
