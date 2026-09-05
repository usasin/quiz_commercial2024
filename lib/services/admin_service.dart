import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Accès Super Admin piloté par Firestore.
///
/// Champs acceptés dans `users/{uid}` :
/// - `isAdmin: true` (champ recommandé)
/// - `admin: true` (compatibilité avec les autres applications)
///
/// Toutes les opérations sensibles sont revalidées côté Firebase Functions.
class AdminService {
  AdminService._();

  static final AdminService instance = AdminService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  bool? _cachedAdmin;
  String? _cachedUid;
  DateTime? _cachedAt;

  bool get cachedIsAdmin => _cachedAdmin ?? false;

  bool _adminFromData(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['isAdmin'] == true || data['admin'] == true;
  }

  Stream<bool> watchIsAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream<bool>.value(false);
    return _firestore.collection('users').doc(user.uid).snapshots().map((snap) {
      final value = _adminFromData(snap.data());
      _cachedUid = user.uid;
      _cachedAdmin = value;
      _cachedAt = DateTime.now();
      return value;
    });
  }

  Future<bool> isAdmin({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      clearCache();
      return false;
    }

    final fresh = _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 2);
    if (!forceRefresh && _cachedUid == user.uid && fresh) {
      return _cachedAdmin ?? false;
    }

    try {
      final snap = await _firestore.collection('users').doc(user.uid).get();
      final value = _adminFromData(snap.data());
      _cachedUid = user.uid;
      _cachedAdmin = value;
      _cachedAt = DateTime.now();
      return value;
    } catch (_) {
      return _cachedUid == user.uid && (_cachedAdmin ?? false);
    }
  }

  void clearCache() {
    _cachedAdmin = null;
    _cachedUid = null;
    _cachedAt = null;
  }

  Future<Map<String, dynamic>> dashboardStats() async {
    return _callMap('adminDashboardStats');
  }

  Future<List<Map<String, dynamic>>> listUsers({String query = ''}) async {
    final result = await _callMap('adminListUsers', {'query': query.trim()});
    final rows = result['users'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listSubscriptions() async {
    final result = await _callMap('adminListSubscriptions');
    final rows = result['subscriptions'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// Accès Premium de TEST. Ne modifie jamais le reçu ni le plan Google Play.
  Future<void> setUserTestPremium({
    required String uid,
    required bool enabled,
  }) async {
    await _callMap('adminSetTestPremium', {
      'uid': uid,
      'enabled': enabled,
    });
  }

  Future<Map<String, dynamic>> loadAppConfig() async {
    return _callMap('adminGetAppConfig');
  }

  Future<void> publishCommunication(Map<String, dynamic> communication) async {
    await _callMap('adminPublishCommunication', {
      'communication': communication,
    });
  }

  Future<void> disableCommunication() async {
    await _callMap('adminPublishCommunication', {
      'communication': {'enabled': false},
    });
  }

  Future<Map<String, dynamic>> loadGamificationConfig() async {
    final result = await loadAppConfig();
    final raw = result['gamification'];
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
  }

  Future<void> publishGamification(
    Map<String, dynamic> gamification,
  ) async {
    await _callMap('adminPublishGamification', {
      'gamification': gamification,
    });
  }

  Future<Map<String, dynamic>> _callMap(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    final result = await _functions.httpsCallable(name).call(data ?? const {});
    if (result.data is Map) {
      return Map<String, dynamic>.from(result.data as Map);
    }
    return <String, dynamic>{};
  }
}
