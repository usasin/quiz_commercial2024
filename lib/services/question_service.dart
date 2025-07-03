// lib/services/question_service.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionService {
  final _rand = Random();

  /*──────────────────
  │  1) Tirage aléatoire (mode "défi")                │
  └──────────────────*/
  Future<List<Map<String, dynamic>>> getRandomQuestions(
      String chapterId, {
        int limit = 10,
      }) async {
    // on récupère TOUTES les questions du chapitre challenge
    final snap = await FirebaseFirestore.instance
        .collection('chapters_challenge')
        .doc(chapterId)
        .collection('questions')
        .get();

    // on mélange puis on garde les {limit} premières
    final all = snap.docs.toList()..shuffle(_rand);
    final sample = all.take(limit);

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

