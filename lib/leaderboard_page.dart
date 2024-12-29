import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:share_plus/share_plus.dart';

import 'drawer/custom_bottom_nav_bar.dart';
import 'screens/profile_page.dart';

class LeaderboardPage extends StatefulWidget {
  @override
  _LeaderboardPageState createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Stream<List<Map<String, dynamic>>> getLeaderboardData() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('totalScore', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return doc.data() as Map<String, dynamic>;
      }).toList();
    });
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
              Colors.white,Colors.white,
              Colors.white60,
              Colors.white54,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80.0, left: 20.0, right: 20.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade800,
                        borderRadius: BorderRadius.circular(15.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white,
                            blurRadius: 5,
                            spreadRadius: 2,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.leaderboard, size: 36, color: Colors.yellow.shade700),
                          const SizedBox(width: 16),
                          AutoSizeText(
                            'Classement',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: getLeaderboardData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Une erreur s\'est produite'));
                  }
                  List<Map<String, dynamic>> leaderboardData = snapshot.data!;

                  // Conteneur statique pour les trois premiers avec le titre à l'intérieur
                  Widget topThreeWidget = Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 15.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade300,
                        borderRadius: BorderRadius.circular(20.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black87.withOpacity(0.5),
                            spreadRadius: 3,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          AutoSizeText(
                            "🏆 Les 3 Meilleurs",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(
                            leaderboardData.length >= 3 ? 3 : leaderboardData.length,
                                (index) {
                              return _buildTopThreeItem(
                                index,
                                leaderboardData[index]['name'] ?? 'Inconnu',
                                leaderboardData[index]['photoURL'],
                                leaderboardData[index]['totalScore'],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );

                  // Conteneur pour la liste complète des participants
                  Widget completeListWidget = Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 15.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black87.withOpacity(0.5),
                            spreadRadius: 3,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoSizeText(
                            "Liste Complète des Participants",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 400, // Limite la hauteur pour activer le défilement
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: AlwaysScrollableScrollPhysics(),
                              itemCount: leaderboardData.length > 3
                                  ? leaderboardData.length - 3
                                  : 0,
                              itemBuilder: (context, index) {
                                index += 3;
                                return _buildParticipantItem(
                                  index,
                                  leaderboardData[index]['name'] ?? 'Inconnu',
                                  leaderboardData[index]['photoURL'],
                                  leaderboardData[index]['totalScore'],
                                );
                              },
                            ),

                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  );

                  return Column(
                    children: [
                      topThreeWidget,
                      completeListWidget,
                    ],
                  );
                },
              )

            ],
          ),
        ),

      ),
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 3,
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
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
              icon: Icon(Icons.leaderboard),
              label: Text("Profil"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopThreeItem(int index, String name, String? photoURL, int score) {
    BoxDecoration boxDecoration;
    Color rankColor;
    String rankText = "";

    if (index == 0) {
      // Couleur or pour le 1er
      boxDecoration = BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white, Colors.white]),
        borderRadius: BorderRadius.circular(50.0),
        boxShadow: [
          BoxShadow(
            color: Colors.amberAccent.withOpacity(0.7),
            spreadRadius: 3,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      );
      rankColor = Colors.amber; // Couleur pour le cadre du 1er
      rankText = "1er";
    } else if (index == 1) {
      // Couleur argent pour le 2e
      boxDecoration = BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white, Colors.white]),
        borderRadius: BorderRadius.circular(50.0),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.shade100.withOpacity(0.5),
            spreadRadius: 3,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      );
      rankColor = Colors.grey; // Couleur pour le cadre du 2e
      rankText = "2e";
    } else {
      // Couleur bronze pour le 3e
      boxDecoration = BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white, Colors.white]),
        borderRadius: BorderRadius.circular(50.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200.withOpacity(0.5),
            spreadRadius: 3,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      );
      rankColor = Colors.brown; // Couleur pour le cadre du 3e
      rankText = "3e";
    }

    return Container(
      height: 60,
      decoration: boxDecoration,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: rankColor, // Applique la couleur pour le cadre du rang
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: AutoSizeText(
                rankText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Texte en blanc pour contraster
                ),
                maxLines: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              radius: 10,
              backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
              child: photoURL == null ? Icon(Icons.person, size: 8) : null,
            ),
          ),
          Expanded(
            child: AutoSizeText(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
              maxLines: 1,
            ),
          ),
          AutoSizeText(
            '$score',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.blue.shade800),
            onPressed: () {
              Share.share('Je suis ${rankText} avec un score de $score sur le classement ! 🎉');
            },
          ),
        ],
      ),
    );
  }


  Widget _buildParticipantItem(
      int index, String name, String? photoURL, int score) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.shade100.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: AutoSizeText(
                "${index + 1}e",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              radius: 10,
              backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
              child: photoURL == null ? Icon(Icons.person, size: 15) : null,
            ),
          ),
          Expanded(
            child: AutoSizeText(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
              maxLines: 1,
            ),
          ),
          AutoSizeText(
            '$score',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.blue.shade800),
            onPressed: () {
              Share.share('Je suis classé ${index + 1}e avec un score de $score ! 🌟');
            },
          ),
        ],
      ),
    );
  }
}
