import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionService {
  Future<List<Map<String, dynamic>>> getQuestions({
    required String chapterId,
    required String levelId,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('chapters')
        .doc(chapterId)
        .collection('levels')
        .doc(levelId)
        .collection('questions')
        .orderBy(FieldPath.documentId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'question': data['question'],
        'options': List<String>.from(data['options']),
        'correctAnswer': data['correctAnswer'],
        'imagePath': data['imagePath'] ?? '',
      };
    }).toList();
  }
}
