import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/module_page.dart';

// Vérifie si un module est débloqué
bool isModuleUnlocked(int unlockedLevels, int moduleIndex, Map<int, int> scoresPerLevel) {
  if (moduleIndex == 0) return true; // Le premier module est toujours débloqué

  int requiredLevels = moduleIndex * 3; // Tous les 3 niveaux
  bool hasRequiredLevels = unlockedLevels >= requiredLevels;

  // Vérifie que le dernier niveau du module précédent a un score ≥ 80
  bool hasRequiredScore = (scoresPerLevel[requiredLevels] ?? 0) >= 80;

  return hasRequiredLevels && hasRequiredScore;
}

// Récupère les niveaux & modules débloqués + scores des niveaux
Future<Map<String, dynamic>> fetchUnlockedData() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return {};

  DocumentSnapshot userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  if (!userDoc.exists) return {};

  final data = userDoc.data() as Map<String, dynamic>? ?? {};
  final unlockedLevels = (data['unlockedLevels'] as Map<String, dynamic>?) ?? {};
  final unlockedModules = (data['unlockedModules'] as Map<String, dynamic>?) ?? {};
  final scoresData = (data['chapters'] as Map<String, dynamic>?) ?? {};

  Map<String, int> unlockedLevelsMap = {};
  Map<String, int> unlockedModulesMap = {};
  Map<String, Map<int, int>> scoresPerChapter = {};

  unlockedLevels.forEach((key, value) {
    unlockedLevelsMap[key] = value as int;
  });

  unlockedModules.forEach((key, value) {
    unlockedModulesMap[key] = value as int;
  });

  scoresData.forEach((chapterId, chapterData) {
    if (chapterData is Map && chapterData['levelScores'] is Map) {
      scoresPerChapter[chapterId] = (chapterData['levelScores'] as Map).map(
            (key, value) => MapEntry(int.parse(key.split(' ')[1]), value as int),
      );
    }
  });

  return {
    'unlockedLevels': unlockedLevelsMap,
    'unlockedModules': unlockedModulesMap,
    'scoresPerChapter': scoresPerChapter,
  };
}

Widget buildLessonCard(
    BuildContext context,
    DocumentSnapshot module,
    int unlockedLevels,
    int unlockedModules,
    Map<int, int> scoresPerLevel,
    String chapterId,
    int moduleIndex,
    ) {
  bool unlocked = isModuleUnlocked(unlockedLevels, moduleIndex, scoresPerLevel);

  // Récupération sécurisée de la description : si le champ n'existe pas, on renvoie une chaîne vide.
  String moduleDescription = '';
  final data = module.data() as Map<String, dynamic>;
  if (data.containsKey('description')) {
    moduleDescription = data['description'] as String? ?? '';
  } else {
    moduleDescription = '';
  }

  return Card(
    elevation: 4,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: unlocked ? Colors.green.shade300 : Colors.grey.shade400,
        width: 2,
      ),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: unlocked ? Colors.green.shade100 : Colors.grey.shade300,
        child: Icon(
          unlocked ? Icons.play_circle_fill : Icons.lock,
          color: unlocked ? Colors.green.shade700 : Colors.grey.shade600,
          size: 28,
        ),
      ),
      title: AutoSizeText(
        data['title'] ?? 'Module ${moduleIndex + 1}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: unlocked ? Colors.blue.shade800 : Colors.grey.shade700,
        ),
        maxLines: 1,
      ),
      subtitle: unlocked
          ? AutoSizeText(
        moduleDescription,
        style: TextStyle(color: Colors.grey.shade700),
        maxLines: 2,
      )
          : AutoSizeText(
        'Débloqué : 3 levels avec score ≥ 80',
        style: TextStyle(
            color: Colors.red.shade700, fontWeight: FontWeight.bold),
        maxLines: 1,
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey.shade600),
      onTap: unlocked
          ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModulePage(
              parcoursNumber: data['parcoursNumber'],
              chapterId: chapterId,
              moduleId: module.id,
            ),
          ),
        );
      }
          : null,
    ),
  );
}

