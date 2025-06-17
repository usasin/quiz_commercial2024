import 'package:cloud_firestore/cloud_firestore.dart';

class Chapter {
  final String title;
  final String id;
  final int numberOfQuizzes;
  final String imageUrl; // Nouveau champ

  Chapter({
    required this.title,
    required this.id,
    required this.numberOfQuizzes,
    required this.imageUrl,
  });

  static Chapter fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Chapter(
      title: data['title'] ?? 'Untitled',
      id: doc.id,
      numberOfQuizzes: data['numberOfQuizzes'] ?? 0,
      imageUrl: data['imageUrl'] ?? '', // Récupération de l'image
    );
  }
}



class Question {
  final String questionText;
  final List<String> choices;
  final String correctAnswer;

  Question({
    required this.questionText,
    required this.choices,
    required this.correctAnswer,
  });

  // Factory method for creating Question instance from a Firestore Map
  static Question fromMap(Map<String, dynamic> data) {
    return Question(
      questionText: data['questionText'] ?? 'No question provided', // Default message if missing
      choices: List<String>.from(data['choices'] ?? []), // Default to empty list if missing
      correctAnswer: data['correctAnswer'] ?? '', // Default to empty string if missing
    );
  }
}
