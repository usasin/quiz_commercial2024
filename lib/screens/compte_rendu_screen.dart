// lib/screens/compte_rendu_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../drawer/custom_bottom_nav_bar.dart';
import '../rotating_glow_border.dart';

class CompteRenduScreen extends StatefulWidget {
  final String chapterId;
  const CompteRenduScreen({required this.chapterId, Key? key}) : super(key: key);

  @override
  State<CompteRenduScreen> createState() => _CompteRenduScreenState();
}

class _CompteRenduScreenState extends State<CompteRenduScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this); // Mode Libre / Mode Apprenant
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chapters')
        .doc(widget.chapterId)
        .get();
    return snap.data() ?? {};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    appBar: AppBar(
      title: const Text('Compte-rendu'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Mode Libre'),
          Tab(text: 'Mode Apprenant'),
        ],
      ),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
        future: _fetch(),
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text('Aucun compte-rendu trouvé'));
          }

          final d = snap.data!;
          return TabBarView(controller: _tabs, children: [
            _tab(
              d['interviewReport'] ?? '',
              (d['stepStatusLibre'] as List?) ?? [],
            ),
            _tab(
              d['learningReport'] ?? '',
              (d['stepStatusGuide'] as List?) ?? [],
            ),
          ]);
        }),
    bottomNavigationBar: CustomBottomNavBar(
      parentContext: context,
      currentIndex: 2,
      scaffoldKey: _scaffoldKey,
    ),
  );

  Widget _tab(String report, List status) {
    if (report.isEmpty) {
      return const Center(child: Text('Aucun rapport disponible'));
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        _gridSteps(status),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _markdown(report),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => Share.share(report, subject: 'Compte-rendu'),
            icon: const Icon(Icons.share),
            label: const Text('Partager'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gridSteps(List status) {
    // Étiquettes des étapes (on boucle si plus de 6)
    const labels = [
      'Introduction',
      'Situation',
      'Découverte',
      'Proposition',
      'Négociation',
      'Conclusion'
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(status.length, (i) {
          final s = status[i] as String;
          Color c;
          String txt;
          switch (s) {
            case 'correct':
              c = Colors.green;
              txt = '✓';
              break;
            case 'partial':
              c = Colors.orange;
              txt = '⚠️';
              break;
            case 'missing':
              c = Colors.red;
              txt = '✗';
              break;
            default:
              c = Colors.grey;
              txt = '${i + 1}';
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotatingGlowBorder(
                borderWidth: 4,
                borderRadius: 12,
                colors: [Colors.white, c, Colors.white],
                duration: const Duration(seconds: 4),
                child: Container(
                  width:  40.0, // remplace "Forty" par 40.0
                  height:  40.0, // remplace "Forty" par 40.0
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: AutoSizeText(
                    txt,
                    style: TextStyle(
                      color: c,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width:  40.0, // remplace "Fifty" par 50.0
                child: AutoSizeText(
                  labels[i % labels.length],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 2,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _markdown(String txt) {
    final lines = txt.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((l) {
        if (l.startsWith('##')) {
          return Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: AutoSizeText(
              l.replaceFirst('##', '').trim(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
              maxLines: 1,
            ),
          );
        } else if (l.startsWith('-')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: AutoSizeText(
                    l.substring(1).trim(),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: AutoSizeText(
              l,
              maxLines: 3,
            ),
          );
        }
      }).toList(),
    );
  }
}
