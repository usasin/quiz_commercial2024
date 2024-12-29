import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/module_page.dart';

// Génère la liste des scores pour débloquer chaque module, de façon dynamique
List<int> generateUnlockScores(int numberOfModules, int increment) {
  List<int> unlockScores = [];
  for (int i = 0; i < numberOfModules; i++) {
    unlockScores.add(i * increment);
  }
  return unlockScores;
}

// Map des scores des chapitres générés dynamiquement
Map<String, List<int>> chapterModuleUnlockScores = {
  for (int i = 1; i <= 20; i++) // Pour supporter plus de 5 chapitres
    'chapter$i': generateUnlockScores(12, 270) // Génère une liste de scores pour chaque chapitre avec un incrément de 270 points
};

// Vérifie si le module est débloqué en fonction du score de l'utilisateur et du chapitre
bool isModuleUnlocked(int? userScore, String chapterId, int moduleIndex) {
  if (userScore == null ||
      !chapterModuleUnlockScores.containsKey(chapterId) ||
      moduleIndex < 0 ||
      moduleIndex >= chapterModuleUnlockScores[chapterId]!.length) {
    return false;
  }
  return userScore >= chapterModuleUnlockScores[chapterId]![moduleIndex];
}

// Construit la carte de leçon en fonction du statut de déblocage
Widget buildLessonCard(BuildContext context, DocumentSnapshot module, int? userScore, String chapterId, int index) {
  // Vérifiez que l'index est valide avant de construire la carte
  if (!chapterModuleUnlockScores.containsKey(chapterId) || index < 0 || index >= chapterModuleUnlockScores[chapterId]!.length) {
    return Container(); // Retournez un container vide si l'index est invalide
  }

  bool unlocked = isModuleUnlocked(userScore, chapterId, index);

  return Card(
    color: unlocked ? Colors.white : Colors.grey.shade200,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: unlocked ? Colors.yellow.shade700 : Colors.grey,
        width: 3,
      ),
    ),
    child: ListTile(
      leading: Icon(
        unlocked ? Icons.play_circle_fill : Icons.lock,
        color: unlocked ? Colors.green : Colors.grey.shade600,
      ),
      title: Center(
        child: Text(
          unlocked ? (module['title'] ?? 'No title') : 'Module ${index + 1}',
          style: TextStyle(
            color: unlocked ? Colors.blue.shade800 : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      subtitle: !unlocked
          ? Center(
        child: Text(
          'Score nécessaire: ${chapterModuleUnlockScores[chapterId]![index]}',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : null,
      onTap: unlocked
          ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModulePage(
              parcoursNumber: index,
              moduleId: module.id,
              chapterId: chapterId, // Vous pouvez maintenant passer le chapitre correctement
            ),
          ),
        );
      }
          : null,
    ),
  );
}
