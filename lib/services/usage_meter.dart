import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_service.dart';

/// Usage / quota meter (SharedPreferences) + Cloud sync (Firestore).
///
/// ✅ Objectif UX "pro":
/// - L'app reste utilisable hors-ligne (prefs = cache local)
/// - Si l'utilisateur est connecté, les droits (Premium + crédits SIM) se
///   synchronisent sur `users/{uid}.entitlements`.
/// - Anti double-livraison des achats (purchase token) pour éviter les bugs.
///
/// ⚠️ Sécurité:
/// - Sans validation serveur des reçus, un utilisateur avancé pourrait tricher.
///   Pour une sécurité "100% pro", ajoute la validation côté backend.
///   (Le présent code vise l'UX et la cohérence multi-devices gratuitement.)
class UsageMeter {
  // --- existing daily quotas (text/audio)

  static const int defaultFreeTextCredits = 25000; // tokens/day
  static const int defaultFreeAudioSeconds = 10 * 60; // seconds/day

  static const String _kPremium = 'is_premium';
  static const String _kActivePlan = 'active_plan';
  static const String _kAdminPreviewFree = 'admin_preview_free';
  static const String _kTextCredits = 'text_credits';
  static const String _kAudioSeconds = 'audio_seconds';
  static const String _kLastResetDay = 'last_reset_day'; // yyyy-mm-dd

  // --- simulation credits

  static const int defaultFreeSimCredits = 1; // one-time
  static const String _kSimCredits = 'sim_credits';
  static const String _kIntensiveExamPasses = 'intensive_exam_passes';

  // --- free quiz levels (global)

  static const int defaultFreeLevelPlays = 3; // one-time global
  static const String _kFreeLevelPlays = 'free_level_plays';

  // --- anti double-delivery
  static const String _kDeliveredPurchaseTokens = 'delivered_purchase_tokens';
  static const int _maxDeliveredTokens = 200;

  // --- cloud sync (debounce to avoid many writes)
  static Timer? _cloudSyncDebounce;

  Future<void> initIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // Premium defaults
    prefs.setBool(_kPremium, prefs.getBool(_kPremium) ?? false);
    prefs.setString(_kActivePlan, prefs.getString(_kActivePlan) ?? 'FREE');

    // Daily reset for text/audio (only if not premium)
    final today = _dayKey(DateTime.now());
    final last = prefs.getString(_kLastResetDay);
    final isPremium = prefs.getBool(_kPremium) ?? false;

    if (!isPremium && last != today) {
      await prefs.setString(_kLastResetDay, today);
      await prefs.setInt(_kTextCredits, defaultFreeTextCredits);
      await prefs.setInt(_kAudioSeconds, defaultFreeAudioSeconds);
    }

    // Ensure keys exist
    if (!prefs.containsKey(_kTextCredits)) {
      await prefs.setInt(_kTextCredits, defaultFreeTextCredits);
    }
    if (!prefs.containsKey(_kAudioSeconds)) {
      await prefs.setInt(_kAudioSeconds, defaultFreeAudioSeconds);
    }

    // One-time counters
    if (!prefs.containsKey(_kSimCredits)) {
      await prefs.setInt(_kSimCredits, defaultFreeSimCredits);
    }
    if (!prefs.containsKey(_kIntensiveExamPasses)) {
      await prefs.setInt(_kIntensiveExamPasses, 0);
    }
    if (!prefs.containsKey(_kFreeLevelPlays)) {
      await prefs.setInt(_kFreeLevelPlays, defaultFreeLevelPlays);
    }

    if (!prefs.containsKey(_kDeliveredPurchaseTokens)) {
      await prefs.setStringList(_kDeliveredPurchaseTokens, <String>[]);
    }
  }

  String _dayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // -------------------------
  // Cloud sync (Firestore)
  // -------------------------

  DocumentReference<Map<String, dynamic>>? _entitlementsRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  /// Pull entitlements from Firestore.
  ///
  /// Merge strategy:
  /// - Premium: si cloud=true => local=true
  /// - Credits: on prend le MAX(local, cloud) par défaut (évite de perdre des crédits hors-ligne)
  Future<void> syncFromCloud({bool takeMaxCredits = true}) async {
    final ref = _entitlementsRef();
    if (ref == null) return;

    try {
      final snap = await ref.get();
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final ent = (data['entitlements'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      final cloudPremium = (ent['isPremium'] as bool?) ?? false;
      final adminPremium = data['isAdmin'] == true || data['admin'] == true;
      final testPremium =
          ((data['testAccess'] as Map?)?['premium'] as bool?) ?? false;
      final cloudCredits = (ent['simCredits'] as num?)?.toInt();
      final intensiveExamPasses =
          (ent['intensiveExamPasses'] as num?)?.toInt() ?? 0;

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_kPremium, cloudPremium || adminPremium || testPremium);

      if (cloudCredits != null) {
        final local = prefs.getInt(_kSimCredits) ?? defaultFreeSimCredits;
        final merged = takeMaxCredits ? max(local, cloudCredits) : cloudCredits;
        await prefs.setInt(_kSimCredits, merged);
      }
      await prefs.setInt(
        _kIntensiveExamPasses,
        max(0, intensiveExamPasses),
      );

      final cloudPlan = ent['activePlan'] as String?;
      await prefs.setString(
        _kActivePlan,
        adminPremium
            ? 'ADMIN'
            : testPremium
                ? 'ADMIN_TEST'
                : (cloudPlan?.isNotEmpty == true ? cloudPlan! : 'FREE'),
      );
    } catch (_) {
      // Silent: offline / permissions / etc.
    }
  }

  /// V2: les droits sont pilotés uniquement par le serveur.
  ///
  /// Ce nom est conservé pour la compatibilité des anciens écrans, mais il ne
  /// pousse plus jamais `isPremium` ou les crédits depuis le téléphone.
  Future<void> pushToCloud() async {
    await syncFromCloud(takeMaxCredits: false);
  }

  void scheduleCloudSync({Duration delay = const Duration(seconds: 2)}) {
    _cloudSyncDebounce?.cancel();
    _cloudSyncDebounce = Timer(delay, () async {
      await syncFromCloud(takeMaxCredits: false);
    });
  }

  // --- anti double-delivery

  Future<bool> wasPurchaseDelivered(String token) async {
    if (token.trim().isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kDeliveredPurchaseTokens) ?? const <String>[];
    return list.contains(token);
  }

  Future<void> markPurchaseDelivered(String token) async {
    token = token.trim();
    if (token.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_kDeliveredPurchaseTokens) ?? <String>[]).toList();
    if (list.contains(token)) return;

    list.add(token);
    if (list.length > _maxDeliveredTokens) {
      list.removeRange(0, list.length - _maxDeliveredTokens);
    }
    await prefs.setStringList(_kDeliveredPurchaseTokens, list);
  }

  // --- premium

  Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    if (await AdminService.instance.isAdmin()) {
      return !(prefs.getBool(_kAdminPreviewFree) ?? false);
    }
    return prefs.getBool(_kPremium) ?? false;
  }

  Future<void> setAdminPreviewFree(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdminPreviewFree, value);
  }

  Future<void> setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPremium, value);
    if (value) {
      await prefs.setString(_kActivePlan, 'PREMIUM');
    }
    scheduleCloudSync();
  }

  Future<void> setActivePlan(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActivePlan, planId);
    scheduleCloudSync();
  }

  Future<String> getActivePlan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActivePlan) ?? 'FREE';
  }

  // --- text credits

  Future<int> getTextCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kTextCredits) ?? defaultFreeTextCredits;
  }

  Future<bool> canUseText(int needed) async {
    if (await isPremium()) return true;
    final c = await getTextCredits();
    return c >= needed;
  }

  Future<void> spendTextTokens(int n) async {
    if (n <= 0) return;
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final c = await getTextCredits();
    await prefs.setInt(_kTextCredits, max(0, c - n));
  }

  // --- audio seconds

  Future<int> getAudioSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kAudioSeconds) ?? defaultFreeAudioSeconds;
  }

  Future<bool> canUseAudio(int neededSeconds) async {
    if (await isPremium()) return true;
    final a = await getAudioSeconds();
    return a >= neededSeconds;
  }

  Future<void> spendAudioSeconds(int seconds) async {
    if (seconds <= 0) return;
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final a = await getAudioSeconds();
    await prefs.setInt(_kAudioSeconds, max(0, a - seconds));
  }

  /// Back-compat helper used by older UI.
  Future<void> addCredits({required int addTextTokens, required int addAudioSeconds}) async {
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final t = await getTextCredits();
    final a = await getAudioSeconds();
    await prefs.setInt(_kTextCredits, max(0, t + addTextTokens));
    await prefs.setInt(_kAudioSeconds, max(0, a + addAudioSeconds));
  }

  // --- simulation credits

  Future<int> getSimCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSimCredits) ?? defaultFreeSimCredits;
  }

  Future<int> getIntensiveExamPasses() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kIntensiveExamPasses) ?? 0;
  }

  Future<bool> canStartSimulation() async {
    if (await isPremium()) return true;
    return (await getSimCredits()) >= 1;
  }

  Future<void> spendSimCredit(int n) async {
    if (n <= 0) return;
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final c = await getSimCredits();
    await prefs.setInt(_kSimCredits, max(0, c - n));
    scheduleCloudSync();
  }

  Future<void> addSimCredits(int n) async {
    if (n <= 0) return;
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final c = await getSimCredits();
    await prefs.setInt(_kSimCredits, max(0, c + n));
    scheduleCloudSync();
  }

  /// Compact / legacy helper used by some pages.
  Future<void> markSimulationUsed() async => spendSimCredit(1);

  // --- free levels (global)

  Future<int> getFreeLevelPlays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kFreeLevelPlays) ?? defaultFreeLevelPlays;
  }

  Future<bool> canPlayLevel() async {
    if (await isPremium()) return true;
    return (await getFreeLevelPlays()) >= 1;
  }

  Future<void> spendLevelPlay(int n) async {
    if (n <= 0) return;
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final c = await getFreeLevelPlays();
    await prefs.setInt(_kFreeLevelPlays, max(0, c - n));
  }
}
