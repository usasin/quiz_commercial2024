// lib/profile_page.dart

import 'dart:io';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lottie/lottie.dart';

import '../animated_gradient_button.dart';
import '../gradient_text.dart';
import '../rotating_glow_border.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// ---------------------------
  ///  Données PROFIL (Firebase)
  /// ---------------------------

  Future<Map<String, dynamic>> getUserDataFromFirestore(String uid) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return (userDoc.data() ?? {}) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'uid': null,
        'email': null,
        'displayName': null,
        'photoURL': null,
      };
    }
    final firestoreData = await getUserDataFromFirestore(user.uid);
    return {
      'uid': user.uid,
      'email': firestoreData['email'] ?? user.email,
      'displayName': firestoreData['name'] ?? user.displayName,
      'photoURL': firestoreData['photoURL'] ?? user.photoURL,
    };
  }

  Future<void> _updateProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseStorage.instance.ref('profileImages/${user.uid}');
    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();

    await user.updatePhotoURL(url);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'photoURL': url});
    if (mounted) setState(() {});
  }

  Future<void> _showUpdateDisplayNameDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Modifier le nom d\'utilisateur'.tr()),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: 'Nom d\'utilisateur'.tr(),
            hintText: 'Entrez votre nouveau nom'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'.tr()),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Le nom ne peut pas être vide.'.tr())),
                );
                return;
              }
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await user.updateDisplayName(name);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'name': name});
                if (mounted) setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Nom d\'utilisateur mis à jour !'.tr())),
                );
              }
              Navigator.pop(context);
            },
            child: Text('Enregistrer'.tr()),
          ),
        ],
      ),
    );
  }

  /// -----------------------------------------
  ///  Scores & Statistiques (chapitres / UI)
  /// -----------------------------------------

  /// Agrège le score total utilisateur.
  Future<int> getTotalScore(String? uid) async {
    if (uid == null) return 0;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final chapters = (doc.data()?['chapters'] as Map<String, dynamic>?) ?? {};
    var total = 0;
    chapters.values.forEach((chap) {
      if (chap is Map<String, dynamic>) {
        total += (chap['totalScore'] as int?) ?? 0;
      }
    });
    return total;
  }

  /// Détails d’un chapitre (titre, nb quizzes/modules).
  Future<Map<String, dynamic>> getChapterDetails(String chapterId) async {
    final chapterDoc =
        await FirebaseFirestore.instance.collection('chapters').doc(chapterId).get();
    return (chapterDoc.data() ?? {}) as Map<String, dynamic>;
  }

  /// Récupère et normalise les données des chapitres pour l’utilisateur courant.
  ///
  /// Retour :
  /// {
  ///   'chapterScores': Map<String, Map<String,int>>,
  ///   'unlockedLevels': Map<String,int>,
  ///   'unlockedModules': Map<String,int>,
  /// }
  Future<Map<String, dynamic>> getChaptersData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = (userDoc.data() ?? {}) as Map<String, dynamic>;

    // Chapitres (scores par niveau)
    final rawChaps = userData['chapters'] as Map<String, dynamic>? ?? {};
    final chapterScores = <String, Map<String, int>>{};
    rawChaps.forEach((chapterId, chapterData) {
      if (chapterData is Map<String, dynamic>) {
        final levelScores =
            chapterData['levelScores'] as Map<String, dynamic>? ?? {};
        final scores = <String, int>{};
        levelScores.forEach((level, val) {
          if (val is int) {
            scores[level] = val;
          } else if (val is Map<String, dynamic> && val['score'] is int) {
            scores[level] = val['score'] as int;
          }
        });
        chapterScores[chapterId] = scores;
      }
    });

    // Niveaux & modules débloqués (top-level)
    final rawUnlockedLv = userData['unlockedLevels'] as Map<String, dynamic>? ?? {};
    final rawUnlockedMd = userData['unlockedModules'] as Map<String, dynamic>? ?? {};
    final unlockedLevels = <String, int>{};
    final unlockedModules = <String, int>{};

    rawUnlockedLv.forEach((k, v) {
      if (v is int) unlockedLevels[k] = v;
    });
    rawUnlockedMd.forEach((k, v) {
      if (v is int) unlockedModules[k] = v;
    });

    return {
      'chapterScores': chapterScores,
      'unlockedLevels': unlockedLevels,
      'unlockedModules': unlockedModules,
    };
  }

  /// -----------------------------------------
  ///  UI
  /// -----------------------------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white54, Colors.white],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          children: [
            const SizedBox(height: 20),

            // -------- Profil (depuis Firestore + Auth) --------
            FutureBuilder<Map<String, dynamic>>(
              future: getProfileData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) return const SizedBox();

                final profile = snapshot.data!;
                final imageUrl = profile['photoURL'] as String?;
                final displayName = (profile['displayName'] as String?) ?? 'Nom inconnu'.tr();
                final email = (profile['email'] as String?) ?? 'Email non défini'.tr();

                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 3,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          key: ValueKey(imageUrl ?? 'default'),
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                              ? NetworkImage(imageUrl)
                              : const AssetImage('assets/images/user.png')
                                  as ImageProvider,
                        ),
                        const SizedBox(height: 10),
                        GradientText(
                          displayName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          gradient: LinearGradient(colors: [
                            Colors.blue.shade800,
                            Colors.blue.shade300,
                            Colors.blue.shade800,
                          ]),
                        ),
                        const SizedBox(height: 8),
                        AnimatedGradientButton(
                          onTap: _showUpdateDisplayNameDialog,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.edit, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Modifier le nom', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          email,
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        AnimatedGradientButton(
                          onTap: _updateProfileImage,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.camera_alt, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Changer la photo', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // -------- Score total --------
            FutureBuilder<int>(
              future: getTotalScore(user?.uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final total = snap.data ?? 0;
                return Column(
                  children: [
                    SizedBox(
                      height: 120, width: 120,
                      child: Lottie.asset('assets/Animation_salesstat.json', fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 16),
                    const GradientText(
                      'Score total global',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      gradient: LinearGradient(colors: [Colors.green, Colors.lightGreen, Colors.green]),
                    ),
                    const SizedBox(height: 8),
                    AnimatedGradientButton(
                      onTap: () {},
                      child: Text(
                        total.toString(),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // -------- Statistiques par chapitre --------
            FutureBuilder<Map<String, dynamic>>(
              future: getChaptersData(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Commencez à jouer pour voir vos statistiques ici.'),
                  );
                }

                final data = snap.data!;
                final scoresMap = data['chapterScores'] as Map<String, Map<String, int>>;
                final levelsMap = data['unlockedLevels'] as Map<String, int>;
                final modsMap   = data['unlockedModules'] as Map<String, int>;

                // Tri des chapitres par score décroissant
                final entries = scoresMap.entries.toList()
                  ..sort((a, b) =>
                      b.value.values.fold(0, (p, e) => p + e)
                          .compareTo(a.value.values.fold(0, (p, e) => p + e)));

                return Column(
                  children: entries.map((entry) {
                    final chapId = entry.key;
                    final scores = entry.value;
                    final chapTotalScore = scores.values.fold(0, (p, e) => p + e);

                    // Dans tes données, unlockedLevels semble compter à partir de 1 (niveau 0 inclus) → on affiche n-1.
                    int rawLevelsUnlocked = levelsMap[chapId] ?? 1;
                    int displayLevelsUnlocked = max(0, rawLevelsUnlocked - 1);
                    int displayModulesUnlocked = modsMap[chapId] ?? 1;

                    return FutureBuilder<Map<String, dynamic>>(
                      future: getChapterDetails(chapId),
                      builder: (c2, s2) {
                        if (s2.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!s2.hasData) return const SizedBox();

                        final chap = s2.data!;
                        final title = chap['title'] as String? ?? 'Chapitre';
                        final nq    = chap['numberOfQuizzes'] as int? ?? 0;
                        final nm    = chap['numberOfModules'] as int? ?? 0;

                        // Dernier score de niveau pour la condition “>=80”
                        int lastLevelScore = 0;
                        if (scores.isNotEmpty) {
                          final nums = <int>[];
                          scores.forEach((level, score) {
                            final n = int.tryParse(level.replaceAll(RegExp(r'\D'), ''));
                            if (n != null) nums.add(n);
                          });
                          if (nums.isNotEmpty) {
                            final maxLevel = nums.reduce((a, b) => a > b ? a : b);
                            lastLevelScore = scores['Level $maxLevel'] ?? 0;
                          }
                        }

                        final levelsDone = displayLevelsUnlocked >= nq;
                        final modsDone   = nm > 0 ? (displayModulesUnlocked >= nm) : true;
                        final finishedByScore = lastLevelScore >= 80;

                        final done = levelsDone && modsDone && finishedByScore;

                        // Heuristique “leçons déverrouillées”
                        final lessons = (chapTotalScore / 240).floor();

                        final box = _buildChapterBox(
                          title,
                          displayLevelsUnlocked,
                          displayModulesUnlocked,
                          lessons,
                          chapTotalScore,
                          done,
                        );

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: done
                              ? RotatingGlowBorder(
                                  borderWidth: 3,
                                  borderRadius: 20,
                                  colors: const [Colors.green, Colors.lightGreen, Colors.green],
                                  duration: const Duration(seconds: 4),
                                  child: box,
                                )
                              : box,
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  /// Box d’un chapitre
  Widget _buildChapterBox(
    String chapterTitle,
    int displayLevelsUnlocked,
    int displayModulesUnlocked,
    int unlockedLessons,
    int totalScore,
    bool isChapterCompleted,
  ) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isChapterCompleted
              ? [Colors.green.shade500, Colors.green.shade100]
              : [Colors.blue.shade800, Colors.blue.shade100],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isChapterCompleted ? Colors.green.shade800 : Colors.transparent,
          width: isChapterCompleted ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 3, blurRadius: 5, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AutoSizeText(
                  chapterTitle,
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: isChapterCompleted ? Colors.green.shade800 : Colors.yellow.shade700,
                  ),
                  maxLines: 1, minFontSize: 12, overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                isChapterCompleted ? Icons.check_circle : Icons.access_alarm,
                color: isChapterCompleted ? Colors.green.shade800 : Colors.yellow.shade700,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatItem('Niveaux déverrouillés'.tr(), displayLevelsUnlocked,
              isCompleted: displayLevelsUnlocked > 0),
          const SizedBox(height: 6),
          _buildStatItem('Modules débloqués'.tr(), displayModulesUnlocked,
              isCompleted: displayModulesUnlocked > 0),
          const SizedBox(height: 6),
          _buildStatItem('Leçons déverrouillées'.tr(), unlockedLessons,
              isCompleted: unlockedLessons > 0),
          const SizedBox(height: 6),
          _buildStatItem('Score total du chapitre'.tr(), totalScore,
              isCompleted: totalScore >= 1000),
          if (isChapterCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Chapitre terminé !'.tr(),
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, {bool isCompleted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white,
            ),
          ),
        ),
        Row(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isCompleted ? Icons.check_circle : Icons.add_alert,
              color: isCompleted ? Colors.green.shade700 : Colors.yellow.shade700,
              size: 18,
            ),
          ],
        ),
      ],
    );
  }
}
