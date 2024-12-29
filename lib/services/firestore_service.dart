import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/models.dart'; // Si la classe Chapter est dans 'models.dart'

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Récupère les chapitres depuis Firestore
  Future<List<Chapter>> getChapters() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('chapters').get();
      return snapshot.docs.map((doc) => Chapter.fromFirestore(doc)).toList();
    } catch (e) {
      print("Erreur lors de la récupération des chapitres : $e");
      return [];
    }
  }

  // Récupère les niveaux déverrouillés pour chaque chapitre d'un utilisateur
  Future<Map<String, int>> fetchUnlockedLevelsByChapter(String userId) async {
    try {
      DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(userId).get();
      final data = userSnapshot.data() as Map<String, dynamic>?;
      return Map<String, int>.from(data?['unlockedLevelsByChapter'] ?? {});
    } catch (e) {
      print("Erreur lors de la récupération des niveaux déverrouillés par chapitre : $e");
      return {};
    }
  }

  // Incrémente le niveau déverrouillé pour un chapitre spécifique
  Future<void> incrementUnlockedLevelForChapter(String userId, String chapterId) async {
    final userRef = _firestore.collection('users').doc(userId);
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot userSnapshot = await transaction.get(userRef);
      Map<String, int> unlockedLevelsByChapter = Map<String, int>.from(userSnapshot.get('unlockedLevelsByChapter') ?? {});
      unlockedLevelsByChapter[chapterId] = (unlockedLevelsByChapter[chapterId] ?? 1) + 1;
      transaction.update(userRef, {'unlockedLevelsByChapter': unlockedLevelsByChapter});
    });
  }
}
