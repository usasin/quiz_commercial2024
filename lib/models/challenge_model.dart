// lib/models/challenge_model.dart

class ChallengePlayer {
  final String uid;
  final String name;
  final int score;
  final bool finished;
  final bool isAccepted;
  final String? photoURL;
  final int timeTaken; // en millisecondes

  ChallengePlayer({
    required this.uid,
    required this.name,
    required this.score,
    required this.finished,
    required this.isAccepted,
    this.photoURL,
    this.timeTaken = 0,
  });

  factory ChallengePlayer.fromMap(String uid, Map<String, dynamic> map) {
    return ChallengePlayer(
      uid: uid,
      name: map['name'] as String? ?? '',
      score: map['score'] as int? ?? 0,
      finished: map['finished'] as bool? ?? false,
      isAccepted: map['isAccepted'] as bool? ?? false,
      photoURL: map['photoURL'] as String?,
      timeTaken: map['timeTaken'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'score': score,
      'finished': finished,
      'isAccepted': isAccepted,
      'photoURL': photoURL,
      'timeTaken': timeTaken,
    };
  }

  ChallengePlayer copyWith({
    String? uid,
    String? name,
    int? score,
    bool? finished,
    bool? isAccepted,
    String? photoURL,
    int? timeTaken,
  }) {
    return ChallengePlayer(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      score: score ?? this.score,
      finished: finished ?? this.finished,
      isAccepted: isAccepted ?? this.isAccepted,
      photoURL: photoURL ?? this.photoURL,
      timeTaken: timeTaken ?? this.timeTaken,
    );
  }
}

class ChallengeModel {
  final String id;
  final String chapterId;
  final String levelId;
  final String createdBy;
  final String status;
  final Map<String, ChallengePlayer> players;

  ChallengeModel({
    required this.id,
    required this.chapterId,
    required this.levelId,
    required this.createdBy,
    required this.status,
    required this.players,
  });

  factory ChallengeModel.fromMap(String id, Map<String, dynamic> map) {
    final rawPlayers = Map<String, dynamic>.from(map['players'] as Map? ?? {});
    final players = <String, ChallengePlayer>{};
    rawPlayers.forEach((uid, data) {
      players[uid] =
          ChallengePlayer.fromMap(uid, Map<String, dynamic>.from(data as Map));
    });

    return ChallengeModel(
      id: id,
      chapterId: map['chapterId'] as String? ?? '',
      levelId: map['levelId'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      status: map['status'] as String? ?? 'waiting',
      players: players,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chapterId': chapterId,
      'levelId': levelId,
      'createdBy': createdBy,
      'status': status,
      'players': players.map((uid, p) => MapEntry(uid, p.toMap())),
    };
  }
}

