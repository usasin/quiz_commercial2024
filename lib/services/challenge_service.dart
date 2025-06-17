// lib/services/challenge_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/challenge_model.dart';

class ChallengeService {
  final _challengeRef = FirebaseFirestore.instance.collection('challenges');

  // 🔹 Créer un nouveau défi
  Future<String> createChallenge({
    required String createdBy,
    required String playerName,
    required String chapterId,
    required String levelId,
  }) async {
    final docRef = _challengeRef.doc();
    final user = FirebaseAuth.instance.currentUser;
    final photoURL = user?.photoURL ?? '';

    final challengeData = ChallengeModel(
      id: docRef.id,
      levelId: levelId,
      chapterId: chapterId,
      createdBy: createdBy,
      status: 'waiting',
      players: {
        // Le créateur est déjà "accepté"
        createdBy: ChallengePlayer(
          uid: createdBy,
          name: playerName,
          score: 0,
          finished: false,
          isAccepted: true,
          photoURL: photoURL,
        ),
      },
    );

    final challengeMap = challengeData.toMap();
    challengeMap['createdAt'] = FieldValue.serverTimestamp();
    await docRef.set(challengeMap);
    return docRef.id;
  }

  // 🔹 Rejoindre un défi existant
  Future<void> joinChallenge({
    required String challengeId,
    required String uid,
    required String name,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final photoURL = user?.photoURL ?? '';

    final challengeDoc = _challengeRef.doc(challengeId);
    final snapshot = await challengeDoc.get();
    if (!snapshot.exists) throw Exception('Défi introuvable');

    await challengeDoc.update({
      'players.$uid': {
        'name': name,
        'score': 0,
        'finished': false,
        'isAccepted': false,
        'photoURL': photoURL,
      }
    });
  }

  // 🔹 Accepter une invitation
  Future<void> acceptChallenge({
    required String challengeId,
    required String uid,
  }) async {
    await _challengeRef.doc(challengeId).update({
      'players.$uid.isAccepted': true,
    });
  }

  // 🔹 Démarrer le défi
  Future<void> startChallenge(String challengeId) async {
    await _challengeRef.doc(challengeId).update({'status': 'started'});
  }

  // 🔹 Mettre à jour le score d’un joueur
  Future<void> updatePlayerScore({
    required String challengeId,
    required String uid,
    required int score,
    required bool finished,
  }) async {
    await _challengeRef.doc(challengeId).update({
      'players.$uid.score': score,
      'players.$uid.finished': finished,
    });
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'totalChallengeScore': FieldValue.increment(score)},
        SetOptions(merge: true));
  }

  // 🔹 Mettre à jour (ajouter) le temps de réponse d’un joueur (en ms)
  Future<void> updatePlayerTime({
    required String challengeId,
    required String uid,
    required int timeToAddMs,
  }) async {
    final docRef = _challengeRef.doc(challengeId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data()!;
      final players = Map<String, dynamic>.from(data['players'] as Map);
      final p = Map<String, dynamic>.from(players[uid] as Map);
      final current = (p['timeTaken'] as int?) ?? 0;
      p['timeTaken'] = current + timeToAddMs;
      players[uid] = p;
      tx.update(docRef, {'players': players});
    });
  }

  // 🔹 Flux en temps réel du défi
  Stream<ChallengeModel> listenToChallenge(String challengeId) {
    return _challengeRef.doc(challengeId).snapshots().map((snap) {
      return ChallengeModel.fromMap(snap.id, snap.data()!);
    });
  }
}

