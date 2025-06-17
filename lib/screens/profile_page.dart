// lib/profile_page.dart

import 'dart:io';

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

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class _ProfilePageState extends State<ProfilePage> {
  /// Récupère depuis Firestore :
  /// - mapping chapterScores
  /// - mapping unlockedLevels
  /// - mapping unlockedModules
  Future<Map<String, dynamic>> getChaptersData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    Map<String, Map<String, int>> chapterScores = {};
    if (userData['chapters'] is Map) {
      userData['chapters'].forEach((chapterId, chapterData) {
        if (chapterData is Map<String, dynamic>) {
          final levelScores =
              chapterData['levelScores'] as Map<String, dynamic>? ?? {};
          Map<String, int> scores = {};
          levelScores.forEach((level, score) {
            scores[level] = score as int;
          });
          chapterScores[chapterId] = scores;
        }
      });
    }

    Map<String, int> unlockedLevels = {};
    if (userData['unlockedLevels'] is Map) {
      userData['unlockedLevels'].forEach((key, value) {
        if (value is int) {
          unlockedLevels[key] = value;
        }
      });
    }

    Map<String, int> unlockedModules = {};
    if (userData['unlockedModules'] is Map) {
      userData['unlockedModules'].forEach((key, value) {
        if (value is int) {
          unlockedModules[key] = value;
        }
      });
    }

    return {
      'chapterScores': chapterScores,
      'unlockedLevels': unlockedLevels,
      'unlockedModules': unlockedModules,
    };
  }

  Future<Map<String, dynamic>> getUserDataFromFirestore(String uid) async {
    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.data() as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'uid': null,
        'email': null,
        'name': null,
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
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final storageRef =
    FirebaseStorage.instance.ref().child('profileImages/${user.uid}');
    final uploadTask = await storageRef.putFile(File(pickedFile.path));
    final imageURL = await uploadTask.ref.getDownloadURL();
    await user.updatePhotoURL(imageURL);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'photoURL': imageURL});
    setState(() {});
  }

  Future<void> _showUpdateDisplayNameDialog() async {
    final displayNameController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifier le nom d\'utilisateur'.tr()),
          content: TextField(
            controller: displayNameController,
            decoration: InputDecoration(
              labelText: 'Nom d\'utilisateur'.tr(),
              hintText: 'Entrez votre nouveau nom'.tr(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'.tr()),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Enregistrer'.tr()),
              onPressed: () async {
                final newName = displayNameController.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Le nom ne peut pas être vide.'.tr()),
                    ),
                  );
                  return;
                }
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    await user.updateDisplayName(newName);
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'name': newName});
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Nom d\'utilisateur mis à jour avec succès !'.tr(),
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Erreur lors de la mise à jour : $e'.tr(),
                        ),
                      ),
                    );
                  }
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<int> getTotalScore(String? uid) async {
    if (uid == null) return 0;
    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data();
    final chapters = userData?['chapters'] as Map<String, dynamic>? ?? {};
    int totalScore = 0;
    chapters.forEach((_, chapterData) {
      if (chapterData is Map<String, dynamic>) {
        totalScore += (chapterData['totalScore'] as int? ?? 0);
      }
    });
    return totalScore;
  }

  Future<Map<String, dynamic>> getChapterDetails(String chapterId) async {
    final chapterDoc = await FirebaseFirestore.instance
        .collection('chapters')
        .doc(chapterId)
        .get();
    return chapterDoc.data() as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white54,
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          children: [
            const SizedBox(height: 20),

            // Section Profil sans bordure autour du Container
            FutureBuilder<Map<String, dynamic>>(
              future: getProfileData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.error, size: 40, color: Colors.red),
                        const SizedBox(height: 10),
                        Text('Erreur lors du chargement du profil'.tr()),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                final profileData = snapshot.data!;
                final imageUrl = profileData['photoURL'] as String?;
                final displayName = profileData['displayName'] as String?;
                final email = profileData['email'] as String?;

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
                      // ← plus de `border:` ici
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: imageUrl != null
                              ? NetworkImage(imageUrl)
                              : const AssetImage('assets/images/user.png')
                          as ImageProvider,
                        ),
                        const SizedBox(height: 10),
                        GradientText(
                          displayName ?? 'Nom inconnu'.tr(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
                            children: [
                              const Icon(Icons.edit, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Modifier le nom'.tr(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          email ?? 'Email non défini'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedGradientButton(
                          onTap: _updateProfileImage,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Changer la photo'.tr(),
                                style: const TextStyle(color: Colors.white),
                              ),
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

            // Section Score Total avec animation Lottie
            FutureBuilder<int>(
              future: getTotalScore(FirebaseAuth.instance.currentUser?.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Erreur lors du calcul du score total'),
                  );
                }
                final totalScore = snapshot.data ?? 0;
                return Column(
                  children: [
                    SizedBox(
                      height: 120,
                      width: 120,
                      child: Lottie.asset(
                        'assets/Animation_salesstat.json',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GradientText(
                      'Score total global'.tr(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      gradient: const LinearGradient(colors: [
                        Colors.green,
                        Colors.lightGreen,
                        Colors.green,
                      ]),
                    ),
                    const SizedBox(height: 8),
                    AnimatedGradientButton(
                      onTap: () {},
                      child: Text(
                        totalScore.toString(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Section Chapitres
            FutureBuilder<Map<String, dynamic>>(
              future: getChaptersData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Commencez à jouer pour voir vos statistiques ici.'),
                  );
                }
                final chaptersData = snapshot.data!;
                final chapterScores =
                chaptersData['chapterScores'] as Map<String, Map<String, int>>;
                final unlockedLevelsMap =
                chaptersData['unlockedLevels'] as Map<String, int>;
                final unlockedModulesMap =
                chaptersData['unlockedModules'] as Map<String, int>;

                // Tri des chapitres par score total décroissant
                final sortedChapters = chapterScores.entries.toList()
                  ..sort((a, b) {
                    final aTotal = a.value.values.fold(0, (p, s) => p + s);
                    final bTotal = b.value.values.fold(0, (p, s) => p + s);
                    return bTotal.compareTo(aTotal);
                  });

                return Column(
                  children: sortedChapters.map((entry) {
                    final chapterId = entry.key;
                    final scores = entry.value;
                    final totalScore = scores.values.fold(0, (p, s) => p + s);

                    // rawLevelsUnlocked inclut aussi le niveau 0
                    int rawLevelsUnlocked = unlockedLevelsMap[chapterId] ?? 1;
                    int displayLevelsUnlocked = rawLevelsUnlocked - 1;
                    if (displayLevelsUnlocked < 0) displayLevelsUnlocked = 0;
                    int displayModulesUnlocked = unlockedModulesMap[chapterId] ?? 1;

                    return FutureBuilder<Map<String, dynamic>>(
                      future: getChapterDetails(chapterId),
                      builder: (context, chapSnap) {
                        if (chapSnap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (chapSnap.hasError || !chapSnap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text("Erreur lors de la récupération des détails du chapitre."),
                          );
                        }
                        final chapterDetails = chapSnap.data!;
                        final chapterTitle =
                            chapterDetails['title'] ?? 'Chapitre $chapterId';

                        final numberOfQuizzes =
                            chapterDetails['numberOfQuizzes'] as int? ?? 0;
                        final numberOfModules =
                            chapterDetails['numberOfModules'] as int? ?? 0;

                        final isLevelsCompleted =
                            displayLevelsUnlocked >= numberOfQuizzes;
                        final isModulesCompleted = (numberOfModules > 0)
                            ? (displayModulesUnlocked >= numberOfModules)
                            : true;

                        int lastLevelScore = 0;
                        if (scores.isNotEmpty) {
                          List<int> levelNums = [];
                          scores.forEach((level, score) {
                            final num = int.tryParse(level.replaceAll(RegExp(r'\D'), ''));
                            if (num != null) levelNums.add(num);
                          });
                          if (levelNums.isNotEmpty) {
                            final maxLevel = levelNums.reduce((a, b) => a > b ? a : b);
                            lastLevelScore = scores["Level $maxLevel"] ?? 0;
                          }
                        }

                        final isChapterCompleted =
                            isLevelsCompleted && isModulesCompleted && (lastLevelScore >= 80);

                        final unlockedLessons = (totalScore / 240).floor();

                        // Box animée si chapitre terminé
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: isChapterCompleted
                              ? RotatingGlowBorder(
                            borderWidth: 3,
                            borderRadius: 20,
                            colors: const [
                              Colors.green,
                              Colors.lightGreen,
                              Colors.green
                            ],
                            duration: const Duration(seconds: 4),
                            child: _buildChapterBox(
                              chapterTitle,
                              displayLevelsUnlocked,
                              displayModulesUnlocked,
                              unlockedLessons,
                              totalScore,
                              isChapterCompleted,
                            ),
                          )
                              : _buildChapterBox(
                            chapterTitle,
                            displayLevelsUnlocked,
                            displayModulesUnlocked,
                            unlockedLessons,
                            totalScore,
                            isChapterCompleted,
                          ),
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

  /// Construction de la box d’un chapitre
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isChapterCompleted ? Colors.green.shade800 : Colors.transparent,
          width: isChapterCompleted ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 3,
            blurRadius: 5,
            offset: const Offset(0, 3),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isChapterCompleted ? Colors.green.shade800 : Colors.yellow.shade700,
                  ),
                  maxLines: 1,
                  minFontSize: 12,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                isChapterCompleted ? Icons.check_circle : Icons.access_alarm,
                color: isChapterCompleted ? Colors.green.shade800 : Colors.yellow.shade700,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatItem(
            'Niveaux déverrouillés'.tr(),
            displayLevelsUnlocked,
            isCompleted: displayLevelsUnlocked > 0,
          ),
          const SizedBox(height: 6),
          _buildStatItem(
            'Modules débloqués'.tr(),
            displayModulesUnlocked,
            isCompleted: displayModulesUnlocked > 0,
          ),
          const SizedBox(height: 6),
          _buildStatItem(
            'Leçons déverrouillées'.tr(),
            unlockedLessons,
            isCompleted: unlockedLessons > 0,
          ),
          const SizedBox(height: 6),
          _buildStatItem(
            'Score total du chapitre'.tr(),
            totalScore,
            isCompleted: totalScore >= 1000,
          ),
          if (isChapterCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Chapitre terminé !'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label,
      int value, {
        bool isCompleted = false,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        Row(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
