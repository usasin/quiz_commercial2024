import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:lottie/lottie.dart';
import '../drawer/custom_bottom_nav_bar.dart';

import '../leaderboard_page.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
bool areAllFeaturesUnlocked(int totalScore, int unlockedLessons, int requiredLessons) {
  return totalScore >= 1700 && unlockedLessons >= requiredLessons;
}

class _ProfilePageState extends State<ProfilePage> {
  Future<Map<String, dynamic>> getUserDataFromFirestore(String uid) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection(
        'users').doc(uid).get();
    return userDoc.data() as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User is not signed in');
      return {
        'uid': null,
        'email': null,
        'name': null,
        'photoURL': null
      };
    }

    Map<String, dynamic> firestoreData = await getUserDataFromFirestore(
        user.uid);

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
    if (pickedFile == null) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    // Télécharger l'image dans Firebase Storage
    final storageRef = FirebaseStorage.instance.ref().child(
        'profileImages/${user.uid}');
    final uploadTask = await storageRef.putFile(File(pickedFile.path));
    final imageURL = await uploadTask.ref.getDownloadURL();

    // Mettre à jour l'URL de la photo dans FirebaseAuth et Firestore
    await user.updatePhotoURL(imageURL);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoURL': imageURL});

    setState(() {});
  }

  Future<void> _showUpdateDisplayNameDialog() async {
    TextEditingController displayNameController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier le nom d\'utilisateur'),
          content: TextField(
            controller: displayNameController,
            decoration: const InputDecoration(
              labelText: 'Nom d\'utilisateur',
              hintText: 'Entrez votre nouveau nom',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Enregistrer'),
              onPressed: () async {
                final newName = displayNameController.text.trim();

                if (newName.isNotEmpty) {
                  final user = FirebaseAuth.instance.currentUser;

                  if (user != null) {
                    try {
                      // Mise à jour dans Firebase Auth
                      await user.updateDisplayName(newName);

                      // Mise à jour dans Firestore
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({'name': newName});

                      // Mise à jour de l'état local
                      setState(() {});

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Nom d\'utilisateur mis à jour avec succès !')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur lors de la mise à jour : $e')),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom ne peut pas être vide.')),
                  );
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
    if (uid == null) {
      return 0;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(
        uid).get();
    final userData = userDoc.data();
    final chapters = userData?['chapters'] as Map<String, dynamic>? ?? {};

    int totalScore = 0;
    chapters.forEach((chapterId, chapterData) {
      if (chapterData is Map<String, dynamic>) {
        totalScore += (chapterData['totalScore'] as int? ?? 0);
      }
    });

    return totalScore;
  }

  Future<int> getUnlockedLevels(String? uid, String chapterId) async {
    if (uid == null) {
      return 0;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(
        uid).get();
    final userData = userDoc.data();
    final chapters = userData?['chapters'] as Map<String, dynamic>? ?? {};

    final chapterData = chapters[chapterId] as Map<String, dynamic>?;

    return chapterData?['unlockedLevels'] ?? 0;
  }

  Future<Map<String, dynamic>> getChapterDetails(String chapterId) async {
    DocumentSnapshot chapterDoc = await FirebaseFirestore.instance.collection(
        'chapters').doc(chapterId).get();
    return chapterDoc.data() as Map<String, dynamic>;
  }

  Future<Map<String, Map<String, int>>> getChapterScores(String? uid) async {
    if (uid == null) {
      return {};
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(
        uid).get();
    final userData = userDoc.data();
    final chapters = userData?['chapters'] as Map<String, dynamic>? ?? {};

    Map<String, Map<String, int>> chapterScores = {};

    chapters.forEach((chapterId, chapterData) {
      if (chapterData is Map<String, dynamic>) {
        final levelScores = chapterData['levelScores'] as Map<String,
            dynamic>? ?? {};
        Map<String, int> scores = {};
        levelScores.forEach((level, score) {
          scores[level] = score as int;
        });
        chapterScores[chapterId] = scores;
      }
    });

    return chapterScores;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

            // Section Profil
            FutureBuilder<Map<String, dynamic>>(
              future: getProfileData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.error, size: 40, color: Colors.red),
                        const SizedBox(height: 10),
                        const Text('Erreur lors du chargement du profil'),
                      ],
                    ),
                  );
                }

                if (snapshot.hasData) {
                  Map<String, dynamic> profileData = snapshot.data!;

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
                        border: Border.all(color: Colors.blue.shade200, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          // Photo de profil avec cadre
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: profileData['photoURL'] != null
                                ? NetworkImage(profileData['photoURL'])
                                : AssetImage('assets/images/successfully.png') as ImageProvider,
                          ),
                          const SizedBox(height: 10),

                          // Nom d'utilisateur
                          Text(
                            profileData['displayName'] ?? "Nom inconnu",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          // Bouton pour modifier le nom
                          ElevatedButton.icon(
                            onPressed: _showUpdateDisplayNameDialog,
                            icon: const Icon(Icons.edit),
                            label: const Text("Modifier le nom"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Email
                          Text(
                            profileData['email'] ?? "Email non défini",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Bouton Changer la photo
                          ElevatedButton.icon(
                            onPressed: _updateProfileImage,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Changer la photo"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Container();
              },
            ),

            const SizedBox(height: 20),

            // Section Score Total
            FutureBuilder<int>(
              future: getTotalScore(FirebaseAuth.instance.currentUser?.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Erreur lors du calcul du score total'));
                }
                if (snapshot.hasData) {
                  int totalScore = snapshot.data!;
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
                      const Text(
                        'Score total global',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        totalScore.toString(),
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  );
                }
                return Container();
              },
            ),

            const SizedBox(height: 20),

            // Section Chapitres
            FutureBuilder<Map<String, Map<String, int>>>(
              future: getChapterScores(FirebaseAuth.instance.currentUser?.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return const Text('Commencez à jouer pour voir vos statistiques ici.');
                }
                if (snapshot.hasData) {
                  final chapterScores = snapshot.data!;

                  // Trier les chapitres par réussite
                  final sortedChapters = chapterScores.entries.toList()
                    ..sort((a, b) {
                      final aTotalScore = a.value.values.reduce((x, y) => x + y);
                      final bTotalScore = b.value.values.reduce((x, y) => x + y);

                      final aLessons = (aTotalScore / 270).floor();
                      final bLessons = (bTotalScore / 270).floor();

                      final aUnlocked = areAllFeaturesUnlocked(aTotalScore, aLessons, 5);
                      final bUnlocked = areAllFeaturesUnlocked(bTotalScore, bLessons, 5);

                      // Les chapitres terminés en premier
                      if (aUnlocked && !bUnlocked) return -1;
                      if (!aUnlocked && bUnlocked) return 1;

                      // Sinon, trier par score total décroissant
                      return bTotalScore.compareTo(aTotalScore);
                    });

                  // Générer les widgets pour les chapitres triés
                  return Column(
                    children: sortedChapters.map((entry) {
                      final chapterId = entry.key;
                      final scores = entry.value;
                      final totalScore = scores.values.reduce((x, y) => x + y);
                      final unlockedLevels = scores.length;
                      final unlockedLessons = (totalScore / 270).floor();

                      return FutureBuilder<Map<String, dynamic>>(
                        future: getChapterDetails(chapterId),
                        builder: (context, chapterSnapshot) {
                          if (chapterSnapshot.connectionState == ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          }
                          if (chapterSnapshot.hasError || !chapterSnapshot.hasData) {
                            return const Text("Erreur lors de la récupération des détails du chapitre.");
                          }

                          final chapterDetails = chapterSnapshot.data!;
                          final chapterTitle = chapterDetails['title'] ?? 'Chapitre $chapterId';

                          return _buildChapterBox(
                            chapterTitle,
                            unlockedLevels,
                            unlockedLessons,
                            totalScore,
                          );
                        },
                      );
                    }).toList(),
                  );
                } else {
                  return Container();
                }
              },
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),

      // Barre de navigation
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 1,
        scaffoldKey: _scaffoldKey,
      ),
      // Nouveau Container en bas pour le bouton Leaderboard
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 5,
              offset: Offset(0, -3),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LeaderboardPage()),
                );
              },
              icon: Icon(Icons.leaderboard),
              label: Text("Top"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterBox(
      String chapterTitle, int unlockedLevels, int unlockedLessons, int totalScore) {
    bool allFeaturesUnlocked = areAllFeaturesUnlocked(
        totalScore, unlockedLessons, 5); // Ex. : 5 leçons pour tout débloquer

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: EdgeInsets.all(10),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: allFeaturesUnlocked
                  ? [Colors.green.shade700, Colors.green.shade300]
                  : [Colors.blue.shade800, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 3,
                blurRadius: 5,
                offset: Offset(0, 3),
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
                      chapterTitle, // Titre du chapitre ici
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow.shade700,
                      ),
                      maxLines: 1,
                      minFontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    allFeaturesUnlocked
                        ? Icons.check_circle
                        : Icons.access_alarm,
                    color: allFeaturesUnlocked
                        ? Colors.green.shade700
                        : Colors.yellow.shade700,
                  ),
                ],
              ),
              SizedBox(height: 10),
              _buildStatItem(
                'Niveaux déverrouillés',
                unlockedLevels,
                isCompleted: unlockedLevels >= 5,
              ),
              _buildStatItem(
                'Leçons déverrouillées',
                unlockedLessons,
                isCompleted: unlockedLessons >= 5,
              ),
              _buildStatItem(
                'Score total du chapitre',
                totalScore,
                isCompleted: totalScore >= 1000,
              ),
              if (allFeaturesUnlocked)
                Center(
                  child: Text(
                    'Toutes les fonctionnalités débloquées!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (allFeaturesUnlocked)
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Icon(
                Icons.verified,
                color: Colors.green.shade700,
                size: 30,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(String label, int value,
      {bool isGlobal = false, bool isCompleted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isGlobal ? Colors.amber : Colors.white,
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
                color: isGlobal ? Colors.amber : Colors.white,
              ),
            ),
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