// lib/leaderboard_page.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'animated_gradient_button.dart';
import 'gradient_text.dart';
import 'rotating_glow_border.dart';
import 'drawer/custom_bottom_nav_bar.dart';
import 'screens/profile_page.dart';

class LeaderboardPage extends StatefulWidget {
  @override
  _LeaderboardPageState createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // -------------------------------------------------------------------------
  // Streams de classement qui injectent aussi l’UID dans chaque Map
  // -------------------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> getLeaderboardData() => FirebaseFirestore
      .instance
      .collection('users')
      .orderBy('totalScore', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['uid'] = doc.id;
    return data;
  }).toList());

  Stream<List<Map<String, dynamic>>> getOnlineLeaderboardData() =>
      FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalChallengeScore', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        return data;
      }).toList());

  // -------------------------------------------------------------------------
  // Widget pour afficher le Podium (Top-3) en mode visuel avec halo animé
  // -------------------------------------------------------------------------
  Widget _PodiumWidget(List<Map<String, dynamic>> topThree, String scoreKey) {
    // On suppose topThree.length >= 3
    final premier = topThree[0];
    final deuxieme = topThree[1];
    final troisieme = topThree[2];

    // Récupère les scores
    int score1 = premier[scoreKey] as int? ?? 0;
    int score2 = deuxieme[scoreKey] as int? ?? 0;
    int score3 = troisieme[scoreKey] as int? ?? 0;

    // Récupère les noms
    String nom1 = premier['name'] ?? 'Inconnu';
    String nom2 = deuxieme['name'] ?? 'Inconnu';
    String nom3 = troisieme['name'] ?? 'Inconnu';

    // Récupère les URLs et les UID
    String? photo1 = premier['photoURL'] as String?;
    String? photo2 = deuxieme['photoURL'] as String?;
    String? photo3 = troisieme['photoURL'] as String?;
    final String uid1 = premier['uid'] as String? ?? '';
    final String uid2 = deuxieme['uid'] as String? ?? '';
    final String uid3 = troisieme['uid'] as String? ?? '';

    // Détermine pour chacun la photo à afficher :
    final String? authUid = FirebaseAuth.instance.currentUser?.uid;
    final String? authPhoto = FirebaseAuth.instance.currentUser?.photoURL;

    ImageProvider? image1 = (photo1 != null && photo1.isNotEmpty)
        ? NetworkImage(photo1)
        : (authUid == uid1 && authPhoto != null && authPhoto.isNotEmpty)
        ? NetworkImage(authPhoto)
        : null;

    ImageProvider? image2 = (photo2 != null && photo2.isNotEmpty)
        ? NetworkImage(photo2)
        : (authUid == uid2 && authPhoto != null && authPhoto.isNotEmpty)
        ? NetworkImage(authPhoto)
        : null;

    ImageProvider? image3 = (photo3 != null && photo3.isNotEmpty)
        ? NetworkImage(photo3)
        : (authUid == uid3 && authPhoto != null && authPhoto.isNotEmpty)
        ? NetworkImage(authPhoto)
        : null;

    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 2e place (à gauche)
          Positioned(
            left: 20,
            bottom: 0,
            child: RotatingGlowBorder(
              borderWidth: 3,
              borderRadius: 12,
              colors: const [Colors.grey, Colors.white70, Colors.grey],
              duration: const Duration(seconds: 4),
              child: Container(
                width: 90,
                height: 130,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: image2,
                      child: image2 == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nom2,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$score2',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 1ère place (centre, plus haute)
          Positioned(
            bottom: 0,
            child: RotatingGlowBorder(
              borderWidth: 4,
              borderRadius: 12,
              colors: const [Colors.amber, Colors.white, Colors.amber],
              duration: const Duration(seconds: 3),
              child: Container(
                width: 110,
                height: 180,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.amber.shade100,
                      backgroundImage: image1,
                      child: image1 == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nom1,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$score1',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3e place (à droite)
          Positioned(
            right: 20,
            bottom: 0,
            child: RotatingGlowBorder(
              borderWidth: 3,
              borderRadius: 12,
              colors: const [Colors.brown, Colors.white, Colors.brown],
              duration: const Duration(seconds: 4),
              child: Container(
                width: 90,
                height: 110,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.brown.shade200,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.brown.shade100,
                      backgroundImage: image3,
                      child: image3 == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nom3,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$score3',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Profil / Classique / En ligne
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: GradientText(
            'Classement'.tr(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            gradient: LinearGradient(colors: [
              Colors.blue.shade800,
              Colors.blue.shade300,
              Colors.blue.shade800,
            ]),
          ),
          bottom: TabBar(
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(
                child: GradientText(
                  'Profil'.tr(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  gradient:
                  const LinearGradient(colors: [Colors.cyan, Colors.blueAccent, Colors.cyan]),
                ),
              ),
              Tab(
                child: GradientText(
                  'Classique'.tr(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  gradient:
                  const LinearGradient(colors: [Colors.cyan, Colors.blueAccent, Colors.cyan]),
                ),
              ),
              Tab(
                child: GradientText(
                  'En ligne'.tr(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  gradient:
                  const LinearGradient(colors: [Colors.cyan, Colors.blueAccent, Colors.cyan]),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          physics: const BouncingScrollPhysics(),
          children: [
            // 1er onglet = ProfilePage
            ProfilePage(),

            // 2e onglet = Classement Classique
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80, top: 20),
              child: _buildLeaderboardSection('totalScore', true),
            ),

            // 3e onglet = Classement En ligne
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80, top: 20),
              child: _buildLeaderboardSection('totalChallengeScore', false),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(
          parentContext: context,
          currentIndex: 2,
          scaffoldKey: _scaffoldKey,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Composant de section (liste) pour afficher podium + reste des participants
  // -------------------------------------------------------------------------
  Widget _buildLeaderboardSection(String scoreKey, bool isClassic) {
    final isOnline = !isClassic;

    // Dégradé plus doux pour la section « En ligne »
    final BoxDecoration boxDeco = isOnline
        ? BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.indigo.shade400, Colors.blue.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
    )
        : BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: boxDeco,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: isClassic ? getLeaderboardData() : getOnlineLeaderboardData(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Une erreur s\'est produite'.tr()));
          }
          final data = snap.data!;
          if (data.isEmpty) {
            return Center(child: Text('Aucun participant'.tr()));
          }

          final topThree = data.take(3).toList();
          final rest = data.length > 3 ? data.sublist(3) : [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  isClassic
                      ? 'assets/images/sam.top.png'
                      : 'assets/images/mode en ligne.png',
                  height: 120,
                ),
              ),

              // Podium animé
              _PodiumWidget(topThree, scoreKey),

              const SizedBox(height: 16),
              Text(
                rest.isEmpty
                    ? 'Pas d\'autres participants'.tr()
                    : 'Liste Complète des Participants'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isOnline ? Colors.white70 : Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 8),
              if (rest.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rest.length,
                  itemBuilder: (ctx, j) {
                    final entry = rest[j];
                    return _buildParticipantItem(
                      j + 3,
                      entry['name'] as String? ?? 'Inconnu',
                      entry['photoURL'] as String?,
                      entry['uid'] as String? ?? '',
                      entry[scoreKey] as int? ?? 0,
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Participant hors Top-3 (avec fallback limité à l’UID connecté)
  // -------------------------------------------------------------------------
  Widget _buildParticipantItem(
      int index, String name, String? photoURL, String uid, int score) {
    final String? authUid = FirebaseAuth.instance.currentUser?.uid;
    final String? authPhoto = FirebaseAuth.instance.currentUser?.photoURL;
    final ImageProvider? imageProvider = (photoURL != null && photoURL.isNotEmpty)
        ? NetworkImage(photoURL)
        : (authUid == uid && authPhoto != null && authPhoto.isNotEmpty)
        ? NetworkImage(authPhoto)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: imageProvider,
          child: imageProvider == null ? const Icon(Icons.person) : null,
        ),
        title: Text(
          name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$score',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        trailing: AnimatedGradientButton(
          onTap: () => Share.share(
            'Je suis classé ${index}e avec un score de $score ! 🌟',
          ),
          child: const Icon(Icons.share, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
