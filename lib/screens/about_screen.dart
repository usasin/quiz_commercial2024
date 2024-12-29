import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../drawer/custom_bottom_nav_bar.dart';

class AboutScreen extends StatefulWidget {
  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    CollectionReference about = FirebaseFirestore.instance.collection('about');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade200,
              Colors.white,
            ],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: about.doc('about').snapshots(),
          builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
            if (snapshot.hasError) {
              return const Text("Quelque chose s'est mal passé");
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (snapshot.data?.data() != null) {
              Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
              return buildContent(data);
            } else {
              return const Text("Aucune donnée disponible");
            }
          },
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 4,  // Mettez l'index de l'onglet actuel ici
        scaffoldKey: GlobalKey<ScaffoldState>(),  // Vous pouvez passer une clé de Scaffold existante si nécessaire
      ),
    );
  }

  Widget buildContent(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(top: 50.0).add(EdgeInsets.all(16.0)),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Text(
                data['title'] ?? 'Titre manquant',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                data['description'] ?? 'Description manquante',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
            ),
            const SizedBox(height: 10),
            Image.asset(
              'assets/images/logo.png', // Chemin de l'image locale
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 10),
            Html(
              data: data['content'] ?? '<p>Contenu manquant</p>',
              style: {
                "body": Style(fontSize: FontSize(14.0)),
                "h1": Style(fontSize: FontSize(24.0), color: Colors.black87),
                "h2": Style(fontSize: FontSize(16.0), color: Colors.black87),
                "strong": Style(fontSize: FontSize(16.0), color: Colors.indigo.shade300),
                "br": Style(backgroundColor: Color(0xFF73ABEC)),
              },
            ),
          ],
        ),
      ),
    );
  }
}
