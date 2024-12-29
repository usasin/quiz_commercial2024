import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../drawer/custom_bottom_nav_bar.dart';

class CompteRenduScreen extends StatefulWidget {
  final String chapterId;

  CompteRenduScreen({
    required this.chapterId,
  });

  @override
  _CompteRenduScreenState createState() => _CompteRenduScreenState();
}

class _CompteRenduScreenState extends State<CompteRenduScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Deux onglets
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> fetchUserData(String chapterId) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot chapterDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('chapters')
            .doc(chapterId)
            .get();

        if (chapterDoc.exists && chapterDoc.data() != null) {
          return chapterDoc.data() as Map<String, dynamic>;
        }
      } catch (e) {
        print("Erreur lors de la récupération des données : $e");
      }
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Compte Rendu"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Mode Libre".tr()),
            Tab(text: "Mode Apprentissage".tr()),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchUserData(widget.chapterId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("Erreur lors de la récupération des données."),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text("Aucun compte rendu trouvé."),
            );
          }

          final chapterData = snapshot.data!;
          final interviewReport = chapterData['interviewReport'] ?? "Pas de rapport d'entretien disponible.";
          final learningReport = chapterData['learningReport'] ?? "Pas de rapport d'apprentissage disponible.";

          return TabBarView(
            controller: _tabController,
            children: [
              _buildReportWithShareOption("Rapport du Mode Libre", interviewReport),
              _buildReportWithShareOption("Rapport du Mode Apprentissage", learningReport),
            ],
          );
        },
      ),
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 2,
        scaffoldKey: _scaffoldKey,
      ),
    );
  }

  Widget _buildReportWithShareOption(String title, String report) {
    if (report.isEmpty) {
      return Center(
        child: Text(
          "$title\n\nAucun rapport disponible.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  SizedBox(height: 16),
                  ...report.split('\n').map((line) {
                    if (line.startsWith("##")) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          line.replaceFirst("##", "").trim(),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800),
                        ),
                      );
                    } else if (line.startsWith("-")) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            Icon(Icons.check, color: Colors.green, size: 14),
                            SizedBox(width: 8),
                            Expanded(child: Text(line.replaceFirst("-", "").trim())),
                          ],
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(line),
                      );
                    }
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
        // Bouton Partager en bas
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _shareReport(report),
            icon: Icon(Icons.share),
            label: Text("Partager le rapport"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
          ),
        ),
      ],
    );
  }

  void _shareReport(String report) {
    if (report.isNotEmpty) {
      Share.share(report, subject: 'Compte Rendu de la Simulation');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Le compte rendu est vide et ne peut pas être partagé.")),
      );
    }
  }
}
