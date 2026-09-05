import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AppCommunication {
  final String id;
  final bool enabled;
  final String kind;
  final String displayMode;
  final String audience;
  final String title;
  final String message;
  final String imageUrl;
  final String actionLabel;
  final String actionUrl;
  final bool dismissible;
  final bool forceUpdate;
  final int minimumBuild;
  final int latestBuild;
  final DateTime? startsAt;
  final DateTime? expiresAt;

  const AppCommunication({
    required this.id,
    required this.enabled,
    required this.kind,
    required this.displayMode,
    required this.audience,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.actionLabel,
    required this.actionUrl,
    required this.dismissible,
    required this.forceUpdate,
    required this.minimumBuild,
    required this.latestBuild,
    this.startsAt,
    this.expiresAt,
  });

  factory AppCommunication.fromMap(Map<String, dynamic> map) {
    DateTime? date(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value)?.toLocal();
      return null;
    }

    return AppCommunication(
      id: '${map['id'] ?? ''}',
      enabled: map['enabled'] == true,
      kind: '${map['kind'] ?? 'announcement'}',
      displayMode: '${map['displayMode'] ?? 'modal'}',
      audience: '${map['audience'] ?? 'all'}',
      title: '${map['title'] ?? ''}',
      message: '${map['message'] ?? ''}',
      imageUrl: '${map['imageUrl'] ?? ''}',
      actionLabel: '${map['actionLabel'] ?? ''}',
      actionUrl: '${map['actionUrl'] ?? ''}',
      dismissible: map['dismissible'] != false,
      forceUpdate: map['forceUpdate'] == true,
      minimumBuild: (map['minimumBuild'] as num?)?.toInt() ?? 0,
      latestBuild: (map['latestBuild'] as num?)?.toInt() ?? 0,
      startsAt: date(map['startsAt']),
      expiresAt: date(map['expiresAt']),
    );
  }

  bool isActiveAt(DateTime now) {
    if (!enabled || title.trim().isEmpty || message.trim().isEmpty) return false;
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (expiresAt != null && now.isAfter(expiresAt!)) return false;
    return true;
  }
}

class AppCommunicationService {
  AppCommunicationService._();

  static Stream<AppCommunication?> watch() async* {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    while (true) {
      try {
        final response = await functions.httpsCallable('publicAppConfig').call();
        final data = response.data;
        if (data is Map && data['communication'] is Map) {
          yield AppCommunication.fromMap(
            Map<String, dynamic>.from(data['communication'] as Map),
          );
        } else {
          yield null;
        }
      } catch (_) {
        yield null;
      }
      await Future<void>.delayed(const Duration(minutes: 5));
    }
  }
}
