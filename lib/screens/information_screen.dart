
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../drawer/custom_bottom_nav_bar.dart';

class InformationScreen extends StatefulWidget {
  @override
  _InformationScreenState createState() => _InformationScreenState();
}

class _InformationScreenState extends State<InformationScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    CollectionReference informations = FirebaseFirestore.instance.collection('informations');

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
          stream: informations.doc('Mentions Légalesid').snapshots(),
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
        currentIndex: 4,
        scaffoldKey: GlobalKey<ScaffoldState>(),
      ),
    );
  }

  Widget buildContent(Map<String, dynamic> data) {
    String? imagePath = data['imagePath'] as String?;

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
            if (imagePath != null)
              Image.asset(
                'assets/images/$imagePath',
                fit: BoxFit.cover,
              )
            else
              const Text('Image non disponible'),
            const SizedBox(height: 10),
            Html(
              data: data['content'] ?? '<p>Contenu manquant</p>',
              style: {
                "body": Style(fontSize: FontSize(14.0)),
                "h1": Style(fontSize: FontSize(24.0), color: Colors.black87),
                "h2": Style(fontSize: FontSize(16.0), color: Colors.black87),
                "strong": Style(fontSize: FontSize(16.0), color: Colors.indigo.shade300),
                "br": Style(backgroundColor: Color(0xFF97EABF)),
              },
            ),
          ],
        ),
      ),
    );
  }
}
