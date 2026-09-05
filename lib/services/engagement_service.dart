import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gamification simple & robuste : Streak + XP + Badges + Leaderboard.
///
/// Objectif : booster la rétention pour un entraînement (quiz + simu) sans
/// transformer l’app en “cours”.
///
/// - Stockage local (SharedPreferences) : OK offline.
/// - Sync Firestore si connecté : multi-device.
/// - Leaderboard optionnel : collection `leaderboard/{uid}`.
class EngagementService {
  static const _kXp = 'eng_xp';
  static const _kStreakCur = 'eng_streak_cur';
  static const _kStreakBest = 'eng_streak_best';
  static const _kLastDay = 'eng_last_day';
  static const _kBadges = 'eng_badges';
  static const _kDailyDay = 'eng_daily_day';
  static const _kDailyProgress = 'eng_daily_progress';
  static const _kDailyBonusDay = 'eng_daily_bonus_day';
  static const _kChallengeId = 'eng_challenge_id';
  static const _kChallengeProgress = 'eng_challenge_progress';
  static const _kChallengeCompleted = 'eng_challenge_completed';
  static const _kRewardedLessons = 'eng_rewarded_lessons';
  static const _kRewardedQuizzes = 'eng_rewarded_quizzes';
  static const _kRewardedSimulations = 'eng_rewarded_simulations';
  static const _kRewardedAssistant = 'eng_rewarded_assistant';

  static final _fire = FirebaseFirestore.instance;
  static final _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');
  static Map<String, dynamic>? _gamificationCache;
  static DateTime? _gamificationCacheAt;
  static String? _hydratedUid;

  /// Liste officielle des badges (id -> label). Garde ça stable (ASO + UX).
  static const Map<String, Map<String, String>> badgeCatalog = {
    'first_quiz': {
      'title': 'Premier quiz',
      'desc': 'Tu as validé ton premier quiz.',
    },
    'first_simulation': {
      'title': 'Première simulation',
      'desc': 'Tu as terminé ta première simulation.',
    },
    'streak_3': {
      'title': 'Série 3 jours',
      'desc': '3 jours d’affilée sur l’app.',
    },
    'streak_7': {
      'title': 'Série 7 jours',
      'desc': '7 jours d’affilée sur l’app.',
    },
    'streak_30': {
      'title': 'Série 30 jours',
      'desc': '30 jours d’affilée sur l’app.',
    },
    'quiz_10': {
      'title': '10 quiz validés',
      'desc': 'Tu as validé 10 quiz.',
    },
    'simu_5': {
      'title': '5 simulations',
      'desc': 'Tu as terminé 5 simulations.',
    },
    'first_lesson': {
      'title': 'Premier apprentissage',
      'desc': 'Tu as terminé ton premier bloc de leçons.',
    },
    'perfect_quiz': {
      'title': 'Sans faute',
      'desc': 'Tu as obtenu 100 % à un quiz.',
    },
    'quiz_25': {
      'title': 'Expert quiz',
      'desc': 'Tu as validé 25 quiz.',
    },
    'simu_10': {
      'title': 'Expert en action',
      'desc': 'Tu as terminé 10 simulations.',
    },
    'oral_90': {
      'title': 'Entretien remarquable',
      'desc': 'Tu as obtenu au moins 90 à une simulation.',
    },
    'xp_500': {
      'title': 'Cap des 500 XP',
      'desc': 'Tu as franchi le premier grand palier.',
    },
    'xp_1500': {
      'title': 'Maîtrise confirmée',
      'desc': 'Tu as atteint 1 500 XP.',
    },
    'streak_14': {
      'title': 'Série 14 jours',
      'desc': 'Deux semaines d’entraînement régulier.',
    },
    'challenge_winner': {
      'title': 'Défi relevé',
      'desc': 'Tu as terminé un défi spécial.',
    },
    'assistant_10': {
      'title': 'Curiosité professionnelle',
      'desc': 'Tu as utilisé le coach pédagogique sur 10 sujets différents.',
    },
  };

  static const List<int> levelThresholds = [0, 150, 350, 650, 1000, 1500, 2200];
  static const List<String> levelTitles = [
    'Découverte',
    'Apprenti',
    'En progression',
    'Autonome',
    'Confirmé',
    'Expert métier',
    'Maître du parcours',
  ];

  static int levelIndexForXp(int xp) {
    var index = 0;
    for (var i = 0; i < levelThresholds.length; i++) {
      if (xp >= levelThresholds[i]) index = i;
    }
    return index;
  }

  static String levelTitleForXp(int xp) => levelTitles[levelIndexForXp(xp)];

  static int levelStartXp(int xp) => levelThresholds[levelIndexForXp(xp)];

  static int nextLevelXp(int xp) {
    final index = levelIndexForXp(xp);
    return index >= levelThresholds.length - 1
        ? levelThresholds.last
        : levelThresholds[index + 1];
  }

  /// Appel à faire au démarrage d’une page clé (ex: LevelsPage) pour
  /// incrémenter le streak 1x/jour.
  static Future<void> recordAppOpen() async {
    await _hydrateFromCloud();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = _dayKey(now);

    final lastDay = prefs.getInt(_kLastDay) ?? 0;
    int cur = prefs.getInt(_kStreakCur) ?? 0;
    int best = prefs.getInt(_kStreakBest) ?? 0;

    if (lastDay == todayKey) {
      // Déjà compté aujourd’hui
      await _syncToCloud();
      return;
    }

    if (lastDay == _dayKey(now.subtract(const Duration(days: 1)))) {
      cur += 1;
    } else {
      cur = 1;
    }
    best = (cur > best) ? cur : best;

    await prefs.setInt(_kLastDay, todayKey);
    await prefs.setInt(_kStreakCur, cur);
    await prefs.setInt(_kStreakBest, best);

    // Badges streak auto
    await _maybeAwardStreakBadges(cur);

    await _syncToCloud();
    await _syncLeaderboard();
  }

  /// À appeler quand un quiz est validé (>=80%).
  static Future<void> recordQuizPassed({required int percent}) =>
      recordQuizPassedForActivity(percent: percent);

  static Future<void> recordQuizPassedForActivity({
    required int percent,
    String? activityId,
  }) async {
    await recordAppOpen();

    // XP : bonus selon performance
    var add = (percent >= 95)
        ? 60
        : (percent >= 90)
            ? 50
            : (percent >= 80)
                ? 40
                : 20;
    if (activityId != null && activityId.isNotEmpty) {
      final firstReward = await _markUnique(_kRewardedQuizzes, activityId);
      if (!firstReward) add = 10;
    }
    await _addXp(add);
    await _recordMissionActivity('quiz', earnedXp: add);

    await _awardBadge('first_quiz');
    if (percent >= 100) await _awardBadge('perfect_quiz');
    await _incrementCounter('quiz_passed_count');

    final q = await _getCounter('quiz_passed_count');
    if (q >= 10) await _awardBadge('quiz_10');
    if (q >= 25) await _awardBadge('quiz_25');

    await _syncToCloud();
    await _syncLeaderboard();
  }

  /// À appeler quand une simulation est terminée (après les écrits).
  /// Le `oralScore` est optionnel.
  static Future<void> recordSimulationCompleted({
    int? oralScore,
    String? activityId,
  }) async {
    await recordAppOpen();

    // XP
    int add = 70;
    if (oralScore != null && oralScore >= 80) add += 20;
    if (activityId != null && activityId.isNotEmpty) {
      final firstReward = await _markUnique(_kRewardedSimulations, activityId);
      if (!firstReward) add = 20;
    }
    await _addXp(add);
    await _recordMissionActivity('simulation', earnedXp: add);

    await _awardBadge('first_simulation');
    await _incrementCounter('simu_done_count');

    final s = await _getCounter('simu_done_count');
    if (s >= 5) await _awardBadge('simu_5');
    if (s >= 10) await _awardBadge('simu_10');
    if (oralScore != null && oralScore >= 90) await _awardBadge('oral_90');

    await _syncToCloud();
    await _syncLeaderboard();
  }

  static Future<bool> recordLessonCompleted({required String activityId}) async {
    await recordAppOpen();
    final firstReward = await _markUnique(_kRewardedLessons, activityId);
    if (!firstReward) return false;
    await _addXp(25);
    await _recordMissionActivity('lesson', earnedXp: 25);
    await _awardBadge('first_lesson');
    await _incrementCounter('lesson_done_count');
    await _syncToCloud();
    await _syncLeaderboard();
    return true;
  }

  static Future<bool> recordAssistantUsed({required String activityId}) async {
    await recordAppOpen();
    final firstReward = await _markUnique(_kRewardedAssistant, activityId);
    if (!firstReward) return false;
    await _addXp(15);
    await _recordMissionActivity('assistant', earnedXp: 15);
    await _incrementCounter('assistant_used_count');
    final count = await _getCounter('assistant_used_count');
    if (count >= 10) await _awardBadge('assistant_10');
    await _syncToCloud();
    await _syncLeaderboard();
    return true;
  }

  static Future<Map<String, dynamic>> getGamificationConfig({
    bool forceRefresh = false,
  }) async {
    final fresh = _gamificationCacheAt != null &&
        DateTime.now().difference(_gamificationCacheAt!) <
            const Duration(minutes: 5);
    if (!forceRefresh && fresh && _gamificationCache != null) {
      return Map<String, dynamic>.from(_gamificationCache!);
    }
    try {
      final result = await _functions
          .httpsCallable('publicGamificationConfig')
          .call();
      final root = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};
      final raw = root['gamification'];
      if (raw is Map) {
        _gamificationCache = Map<String, dynamic>.from(raw);
        _gamificationCacheAt = DateTime.now();
      }
    } catch (e) {
      debugPrint('EngagementService config error: $e');
    }
    return Map<String, dynamic>.from(
      _gamificationCache ??
          const {
            'enabled': true,
            'dailyGoal': 3,
            'dailyBonusXp': 25,
            'challenge': {'enabled': false},
          },
    );
  }

  // --------------------------- Lecture (UI) ---------------------------

  static Future<int> getXpLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kXp) ?? 0;
  }

  static Future<int> getStreakCurrentLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kStreakCur) ?? 0;
  }

  static Future<int> getStreakBestLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kStreakBest) ?? 0;
  }

  static Future<Set<String>> getBadgesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kBadges) ?? const <String>[]).toSet();
  }

  static Future<Map<String, dynamic>> getMissionProgressLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final config = await getGamificationConfig();
    final today = _dayKey(DateTime.now());
    final dailyProgress = prefs.getInt(_kDailyDay) == today
        ? prefs.getInt(_kDailyProgress) ?? 0
        : 0;
    final challenge = config['challenge'] is Map
        ? Map<String, dynamic>.from(config['challenge'] as Map)
        : <String, dynamic>{};
    final challengeId = '${challenge['id'] ?? ''}';
    final challengeProgress = prefs.getString(_kChallengeId) == challengeId
        ? prefs.getInt(_kChallengeProgress) ?? 0
        : 0;
    return {
      'dailyProgress': dailyProgress,
      'dailyGoal': (config['dailyGoal'] as num?)?.toInt() ?? 3,
      'dailyBonusXp': (config['dailyBonusXp'] as num?)?.toInt() ?? 25,
      'challengeProgress': challengeProgress,
      'challengeCompleted': prefs.getString(_kChallengeId) == challengeId &&
          (prefs.getBool(_kChallengeCompleted) ?? false),
      'challenge': challenge,
    };
  }

  // --------------------------- Helpers ---------------------------

  static int _dayKey(DateTime dt) => (dt.year * 10000) + (dt.month * 100) + dt.day;

  static Future<void> _addXp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final xp = (prefs.getInt(_kXp) ?? 0) + amount;
    await prefs.setInt(_kXp, xp);
    if (xp >= 500) await _awardBadge('xp_500');
    if (xp >= 1500) await _awardBadge('xp_1500');
  }

  static Future<bool> _markUnique(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final values = (prefs.getStringList(key) ?? const <String>[]).toSet();
    if (values.contains(value)) return false;
    values.add(value);
    await prefs.setStringList(key, values.toList());
    return true;
  }

  static Future<void> _recordMissionActivity(
    String type, {
    required int earnedXp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final config = await getGamificationConfig();
    if (config['enabled'] == false) return;
    final today = _dayKey(DateTime.now());
    if (prefs.getInt(_kDailyDay) != today) {
      await prefs.setInt(_kDailyDay, today);
      await prefs.setInt(_kDailyProgress, 0);
    }
    final dailyGoal = (config['dailyGoal'] as num?)?.toInt() ?? 3;
    final dailyProgress = (prefs.getInt(_kDailyProgress) ?? 0) + 1;
    await prefs.setInt(_kDailyProgress, dailyProgress);
    if (dailyProgress >= dailyGoal &&
        prefs.getInt(_kDailyBonusDay) != today) {
      await prefs.setInt(_kDailyBonusDay, today);
      await _addXp((config['dailyBonusXp'] as num?)?.toInt() ?? 25);
    }

    final rawChallenge = config['challenge'];
    if (rawChallenge is! Map) return;
    final challenge = Map<String, dynamic>.from(rawChallenge);
    if (challenge['enabled'] != true) return;
    final challengeId = '${challenge['id'] ?? ''}';
    if (challengeId.isEmpty) return;
    final startsAt = DateTime.tryParse('${challenge['startsAt'] ?? ''}');
    final expiresAt = DateTime.tryParse('${challenge['expiresAt'] ?? ''}');
    final now = DateTime.now();
    if ((startsAt != null && now.isBefore(startsAt)) ||
        (expiresAt != null && now.isAfter(expiresAt))) return;
    if (prefs.getString(_kChallengeId) != challengeId) {
      await prefs.setString(_kChallengeId, challengeId);
      await prefs.setInt(_kChallengeProgress, 0);
      await prefs.setBool(_kChallengeCompleted, false);
    }
    if (prefs.getBool(_kChallengeCompleted) == true) return;
    final metric = '${challenge['metric'] ?? 'quiz'}';
    final increment = metric == 'xp' ? earnedXp : (metric == type ? 1 : 0);
    if (increment <= 0) return;
    final progress = (prefs.getInt(_kChallengeProgress) ?? 0) + increment;
    await prefs.setInt(_kChallengeProgress, progress);
    final target = (challenge['target'] as num?)?.toInt() ?? 5;
    if (progress >= target) {
      await prefs.setBool(_kChallengeCompleted, true);
      await _addXp((challenge['bonusXp'] as num?)?.toInt() ?? 150);
      await _awardBadge('challenge_winner');
    }
  }

  static Future<void> _awardBadge(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_kBadges) ?? const <String>[]).toSet();
    if (list.contains(id)) return;
    list.add(id);
    await prefs.setStringList(_kBadges, list.toList());
  }

  static Future<void> _maybeAwardStreakBadges(int cur) async {
    if (cur >= 3) await _awardBadge('streak_3');
    if (cur >= 7) await _awardBadge('streak_7');
    if (cur >= 14) await _awardBadge('streak_14');
    if (cur >= 30) await _awardBadge('streak_30');
  }

  static Future<void> _incrementCounter(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getInt('eng_cnt_$key') ?? 0) + 1;
    await prefs.setInt('eng_cnt_$key', v);
  }

  static Future<int> _getCounter(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('eng_cnt_$key') ?? 0;
  }

  static User? _user() => FirebaseAuth.instance.currentUser;

  static Future<void> _hydrateFromCloud() async {
    final user = _user();
    if (user == null || _hydratedUid == user.uid) return;
    try {
      final snap = await _fire.collection('users').doc(user.uid).get();
      final raw = snap.data()?['engagement'];
      if (raw is! Map) {
        _hydratedUid = user.uid;
        return;
      }
      final cloud = Map<String, dynamic>.from(raw);
      final prefs = await SharedPreferences.getInstance();
      final localXp = prefs.getInt(_kXp) ?? 0;
      final cloudXp = (cloud['xp'] as num?)?.toInt() ?? 0;
      await prefs.setInt(_kXp, localXp > cloudXp ? localXp : cloudXp);
      final cloudLastDay = (cloud['lastDay'] as num?)?.toInt() ?? 0;
      if (cloudLastDay >= (prefs.getInt(_kLastDay) ?? 0)) {
        await prefs.setInt(_kLastDay, cloudLastDay);
        await prefs.setInt(
          _kStreakCur,
          (cloud['streakCurrent'] as num?)?.toInt() ?? 0,
        );
      }
      final best = (cloud['streakBest'] as num?)?.toInt() ?? 0;
      if (best > (prefs.getInt(_kStreakBest) ?? 0)) {
        await prefs.setInt(_kStreakBest, best);
      }
      final localBadges =
          (prefs.getStringList(_kBadges) ?? const <String>[]).toSet();
      final cloudBadges = cloud['badges'];
      if (cloudBadges is Map) {
        localBadges.addAll(
          cloudBadges.entries
              .where((entry) => entry.value == true)
              .map((entry) => entry.key.toString()),
        );
        await prefs.setStringList(_kBadges, localBadges.toList());
      }
      final cloudDailyDay = (cloud['dailyDay'] as num?)?.toInt() ?? 0;
      if (cloudDailyDay >= (prefs.getInt(_kDailyDay) ?? 0)) {
        await prefs.setInt(_kDailyDay, cloudDailyDay);
        await prefs.setInt(
          _kDailyProgress,
          (cloud['dailyProgress'] as num?)?.toInt() ?? 0,
        );
      }
      final challenge = cloud['challenge'];
      if (challenge is Map && '${challenge['id'] ?? ''}'.isNotEmpty) {
        final cloudChallengeId = '${challenge['id']}';
        final sameChallenge = prefs.getString(_kChallengeId) == cloudChallengeId;
        final localProgress = sameChallenge
            ? prefs.getInt(_kChallengeProgress) ?? 0
            : 0;
        final cloudProgress =
            (challenge['progress'] as num?)?.toInt() ?? 0;
        await prefs.setString(_kChallengeId, cloudChallengeId);
        await prefs.setInt(
          _kChallengeProgress,
          localProgress > cloudProgress ? localProgress : cloudProgress,
        );
        await prefs.setBool(
          _kChallengeCompleted,
          (sameChallenge &&
                  (prefs.getBool(_kChallengeCompleted) ?? false)) ||
              challenge['completed'] == true,
        );
      }
      final counters = cloud['counters'];
      if (counters is Map) {
        for (final key in [
          'lesson_done_count',
          'quiz_passed_count',
          'simu_done_count',
          'assistant_used_count',
        ]) {
          final cloudValue = (counters[key] as num?)?.toInt() ?? 0;
          final prefKey = 'eng_cnt_$key';
          if (cloudValue > (prefs.getInt(prefKey) ?? 0)) {
            await prefs.setInt(prefKey, cloudValue);
          }
        }
      }
      _hydratedUid = user.uid;
    } catch (e) {
      debugPrint('EngagementService hydrate error: $e');
    }
  }

  static Future<void> _syncToCloud() async {
    final u = _user();
    if (u == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final xp = prefs.getInt(_kXp) ?? 0;
      final cur = prefs.getInt(_kStreakCur) ?? 0;
      final best = prefs.getInt(_kStreakBest) ?? 0;
      final lastDay = prefs.getInt(_kLastDay) ?? 0;
      final badges = (prefs.getStringList(_kBadges) ?? const <String>[]).toSet();
      final dailyDay = prefs.getInt(_kDailyDay) ?? 0;
      final dailyProgress = prefs.getInt(_kDailyProgress) ?? 0;
      final challengeId = prefs.getString(_kChallengeId) ?? '';
      final challengeProgress = prefs.getInt(_kChallengeProgress) ?? 0;
      final challengeCompleted = prefs.getBool(_kChallengeCompleted) ?? false;
      final lessonCount = prefs.getInt('eng_cnt_lesson_done_count') ?? 0;
      final quizCount = prefs.getInt('eng_cnt_quiz_passed_count') ?? 0;
      final simulationCount = prefs.getInt('eng_cnt_simu_done_count') ?? 0;
      final assistantCount = prefs.getInt('eng_cnt_assistant_used_count') ?? 0;

      final badgeMap = <String, bool>{
        for (final b in badges) b: true,
      };

      await _fire.collection('users').doc(u.uid).set(
        {
          'engagement': {
            'xp': xp,
            'streakCurrent': cur,
            'streakBest': best,
            'lastDay': lastDay,
            'badges': badgeMap,
            'dailyDay': dailyDay,
            'dailyProgress': dailyProgress,
            'challenge': {
              'id': challengeId,
              'progress': challengeProgress,
              'completed': challengeCompleted,
            },
            'counters': {
              'lesson_done_count': lessonCount,
              'quiz_passed_count': quizCount,
              'simu_done_count': simulationCount,
              'assistant_used_count': assistantCount,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('EngagementService._syncToCloud error: $e');
    }
  }

  static Future<void> _syncLeaderboard() async {
    final u = _user();
    if (u == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final xp = prefs.getInt(_kXp) ?? 0;
      final best = prefs.getInt(_kStreakBest) ?? 0;

      await _fire.collection('leaderboard').doc(u.uid).set(
        {
          'uid': u.uid,
          'name': u.displayName ?? 'Utilisateur',
          'photoUrl': u.photoURL,
          'xp': xp,
          'level': levelIndexForXp(xp) + 1,
          'levelTitle': levelTitleForXp(xp),
          'streakBest': best,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('EngagementService._syncLeaderboard error: $e');
    }
  }
}
