import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Source unique du parcours choisi.
///
/// La copie locale évite qu'un écran ouvert immédiatement après un changement
/// de parcours retombe sur l'ancienne valeur Firestore.
class ActiveTrackService {
  static const _preferenceKey = 'emploiboost_active_track';

  static String _clean(String? value) => (value ?? '').trim().toLowerCase();

  static Future<String> resolve({
    String? requestedTrackId,
    String fallback = 'sales',
  }) async {
    final requested = _clean(requestedTrackId);
    if (requested.isNotEmpty) {
      await _saveLocal(requested);
      return requested;
    }

    final preferences = await SharedPreferences.getInstance();
    final local = _clean(preferences.getString(_preferenceKey));
    if (local.isNotEmpty) return local;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final remote = _clean(snapshot.data()?['activeTrack']?.toString());
        if (remote.isNotEmpty) {
          await _saveLocal(remote);
          return remote;
        }
      } catch (_) {
        // Le parcours local ou le fallback garde l'application utilisable.
      }
    }

    return _clean(fallback).isEmpty ? 'sales' : _clean(fallback);
  }

  static Future<void> select(String trackId) async {
    final track = _clean(trackId);
    if (track.isEmpty) return;

    // Sauvegarde locale en premier : la navigation suivante est cohérente,
    // même avec une connexion lente.
    await _saveLocal(track);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {'activeTrack': track},
      SetOptions(merge: true),
    );
  }

  static Future<void> _saveLocal(String track) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, track);
  }
}
