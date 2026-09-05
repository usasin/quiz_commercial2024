import 'package:cloud_functions/cloud_functions.dart';

class AiTrainingSession {
  final String id;
  final String type;
  final String tier;
  final String accessSource;
  final int maxTurns;
  final DateTime? expiresAt;

  const AiTrainingSession({
    required this.id,
    required this.type,
    required this.tier,
    required this.accessSource,
    required this.maxTurns,
    required this.expiresAt,
  });

  factory AiTrainingSession.fromMap(Map<String, dynamic> data) {
    return AiTrainingSession(
      id: '${data['sessionId'] ?? ''}',
      type: '${data['type'] ?? 'guided'}',
      tier: '${data['tier'] ?? 'free'}',
      accessSource: '${data['accessSource'] ?? ''}',
      maxTurns: (data['maxTurns'] as num?)?.toInt() ?? 5,
      expiresAt: DateTime.tryParse('${data['expiresAt'] ?? ''}'),
    );
  }
}

class AiTrainingAccessException implements Exception {
  final String reason;
  final String message;
  final DateTime? nextIncludedExamAt;

  const AiTrainingAccessException({
    required this.reason,
    required this.message,
    this.nextIncludedExamAt,
  });

  String localizedMessage(String languageCode) {
    if (languageCode != 'en') return message;
    switch (reason) {
      case 'unauthenticated':
        return 'Sign in to start an AI training session.';
      case 'discovery_used':
      case 'resource-exhausted':
        return 'Your included guided sessions have been used. Upgrade to Premium to continue.';
      case 'invalid_session':
        return 'The session could not start. Try again.';
      default:
        return 'Guided training is temporarily unavailable.';
    }
  }

  @override
  String toString() => message;
}

class AiTrainingSessionService {
  AiTrainingSessionService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> access() async {
    try {
      final result = await _functions.httpsCallable('aiTrainingAccess').call();
      return _map(result.data);
    } on FirebaseFunctionsException catch (error) {
      throw _accessError(error);
    }
  }

  static Future<AiTrainingSession> startGuided({
    required String scenarioId,
    String? track,
  }) {
    return _start(type: 'guided', scenarioId: scenarioId, track: track);
  }

  static Future<AiTrainingSession> startExam({
    required String scenarioId,
    String? track,
  }) {
    return _start(type: 'exam', scenarioId: scenarioId, track: track);
  }

  static Future<AiTrainingSession> _start({
    required String type,
    required String scenarioId,
    String? track,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('aiStartTrainingSession')
          .call({'type': type, 'scenarioId': scenarioId, 'track': track});
      final session = AiTrainingSession.fromMap(_map(result.data));
      if (session.id.isEmpty) {
        throw const AiTrainingAccessException(
          reason: 'invalid_session',
          message: 'La séance n’a pas pu démarrer. Réessaie.',
        );
      }
      return session;
    } on FirebaseFunctionsException catch (error) {
      throw _accessError(error);
    }
  }

  static AiTrainingAccessException _accessError(
    FirebaseFunctionsException error,
  ) {
    final details = _map(error.details);
    return AiTrainingAccessException(
      reason: '${details['reason'] ?? error.code}',
      message:
          error.message ??
          'L’entraînement guidé est momentanément indisponible.',
      nextIncludedExamAt: DateTime.tryParse(
        '${details['nextIncludedExamAt'] ?? ''}',
      ),
    );
  }
}
