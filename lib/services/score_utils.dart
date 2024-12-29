import 'package:cloud_firestore/cloud_firestore.dart';
// Pour l'authentification Firebase

Future<void> updateUserTotalScore(String userId, String chapterId, String levelKey, int newScore) async {
  DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);
  DocumentSnapshot userDoc = await userRef.get();
  Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>? ?? {};

  // Accédez ou créez la structure des chapitres si elle n'existe pas
  Map<String, dynamic> chapters = userData['chapters'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> chapterData = chapters[chapterId] as Map<String, dynamic>? ?? {};

  Map<String, dynamic> levelScores = chapterData['levelScores'] as Map<String, dynamic>? ?? {};

  // Mettez à jour le score pour le niveau si le nouveau score est plus élevé
  if (!levelScores.containsKey(levelKey) || newScore > (levelScores[levelKey] as int? ?? 0)) {
    levelScores[levelKey] = newScore;
  }

  // Calculez le score total pour ce chapitre
  int chapterTotalScore = levelScores.values.fold(0, (sum, value) => sum + (int.tryParse(value.toString()) ?? 0));

  // Mettez à jour les données du chapitre
  chapterData['levelScores'] = levelScores;
  chapterData['totalScore'] = chapterTotalScore; // Stockez le score total du chapitre

  // Mettez à jour les données du chapitre dans Firestore
  await userRef.update({
    'chapters.$chapterId': chapterData,
  });

  // Calculez le totalScore pour tous les chapitres
  int totalScore = 0;
  chapters.forEach((id, data) {
    totalScore += (data['totalScore'] as int? ?? 0);
  });

  // Mettez à jour le totalScore au niveau de l'utilisateur
  await userRef.update({
    'totalScore': totalScore,
  });
}
