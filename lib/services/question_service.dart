// lib/services/question_service.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionService {
  final _rand = Random();

  /*──────────────────
  │  1) Tirage aléatoire (mode "défi")                │
  └──────────────────*/
// lib/services/question_service.dart
  Future<List<Map<String, dynamic>>> getRandomQuestions(
      String chapterId, {
        int limit = 10,
      }) async {
    // 1) on récupère tous les levels du chapitre
    final levelSnap = await FirebaseFirestore.instance
        .collection('chapters_challenge')
        .doc(chapterId)
        .collection('levels')
        .get();

    // 2) on agrège les questions de chaque level
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> all = [];
    for (final levelDoc in levelSnap.docs) {
      final qSnap = await levelDoc.reference
          .collection('questions')
          .get();
      all.addAll(qSnap.docs);
    }

    if (all.isEmpty) return [];

    // 3) mélange + échantillon aléatoire
    all.shuffle(_rand);
    final sample = all.take(limit).toList();

    return sample.map((d) {
      final m = d.data();
      return {
        'question'     : m['question'],
        'options'      : List<String>.from(m['options']),
        'correctAnswer': m['correctAnswer'],
        'points'       : m['points'] ?? 1,
      };
    }).toList();
  }


  /*──────────────────
  │ 2) Ancienne méthode (chapters/levels)             │
  └──────────────────*/
  Future<List<Map<String, dynamic>>> getQuestions({
    required String chapterId,
    required String levelId,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection('chapters')
        .doc(chapterId)
        .collection('levels')
        .doc(levelId)
        .collection('questions')
        .orderBy(FieldPath.documentId)
        .get();

    return snap.docs.map((d) {
      final m = d.data();
      return {
        'question'     : m['question'],
        'options'      : List<String>.from(m['options']),
        'correctAnswer': m['correctAnswer'],
        'points'       : m['points'] ?? 1,
      };
    }).toList();
  }
}
