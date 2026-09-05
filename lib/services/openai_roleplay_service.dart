import 'package:cloud_functions/cloud_functions.dart';

/// Client V2 sécurisé : aucun secret OpenAI n'est présent dans l'application.
/// Tous les appels passent par des fonctions Firebase authentifiées.
class OpenAiRoleplayService {
  OpenAiRoleplayService({this.languageCode = 'fr'});

  final String languageCode;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  String _t({required String fr, required String en}) =>
      languageCode == 'en' ? en : fr;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  Exception _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return Exception(
            _t(
              fr: 'Connecte-toi pour utiliser le coach IA.',
              en: 'Sign in to use the AI coach.',
            ),
          );
        case 'resource-exhausted':
          return Exception(
            _t(
              fr: 'Ta séance est complète. Relis les conseils du coach avant le prochain essai.',
              en: 'Your session is complete. Review the coach feedback before your next attempt.',
            ),
          );
        case 'permission-denied':
          return Exception(
            _t(
              fr: 'Cette correction détaillée est réservée à Premium.',
              en: 'This detailed correction is available with Premium.',
            ),
          );
        case 'deadline-exceeded':
          return Exception(
            _t(
              fr: 'Le coach met trop de temps à répondre. Réessaie.',
              en: 'The coach is taking too long to respond. Try again.',
            ),
          );
        case 'unavailable':
        case 'failed-precondition':
          return Exception(
            _t(
              fr: 'Coach IA temporairement indisponible.',
              en: 'AI coach temporarily unavailable.',
            ),
          );
      }
      return Exception(
        error.message ??
            _t(fr: 'Coach IA indisponible.', en: 'AI coach unavailable.'),
      );
    }
    if (error is Exception) return error;
    return Exception(
      _t(
        fr: 'Coach IA indisponible. Réessaie dans un instant.',
        en: 'AI coach unavailable. Try again shortly.',
      ),
    );
  }

  Future<String> send({
    required String scenarioId,
    required Map<String, dynamic> persona,
    required List<Map<String, String>> history,
    required String userMessage,
    Map<String, dynamic>? scenarioData,
    String? track,
    bool examMode = false,
    String? sessionId,
  }) async {
    try {
      final result = await _functions.httpsCallable('aiRoleplay').call({
        'scenarioId': scenarioId,
        'persona': persona,
        'history': history,
        'userMessage': userMessage,
        'scenarioData': scenarioData ?? const <String, dynamic>{},
        'track': track,
        'examMode': examMode,
        'sessionId': sessionId,
        'locale': languageCode,
      });
      final text = (_map(result.data)['text'] ?? '').toString().trim();
      if (text.isEmpty) {
        throw Exception(_t(fr: 'Réponse vide.', en: 'Empty response.'));
      }
      return text;
    } catch (error) {
      throw _friendlyError(error);
    }
  }

  Future<Map<String, dynamic>> coachFeedback({
    required String scenarioId,
    required Map<String, dynamic> persona,
    required List<Map<String, String>> transcript,
    Map<String, dynamic>? scenarioData,
    String? track,
    bool examMode = false,
    String? sessionId,
  }) async {
    try {
      final result = await _functions.httpsCallable('aiCoachFeedback').call({
        'scenarioId': scenarioId,
        'persona': persona,
        'transcript': transcript,
        'scenarioData': scenarioData ?? const <String, dynamic>{},
        'track': track,
        'examMode': examMode,
        'sessionId': sessionId,
        'locale': languageCode,
      });
      return _map(_map(result.data)['feedback']);
    } catch (error) {
      throw _friendlyError(error);
    }
  }

  Future<Map<String, dynamic>> correctSynthesis({
    required String scenarioId,
    required Map<String, dynamic> persona,
    required List<Map<String, String>> transcript,
    required String synthesisText,
    Map<String, dynamic>? scenarioData,
    String? track,
    String? sessionId,
  }) {
    return _correctWriting(
      kind: 'synthesis',
      scenarioId: scenarioId,
      persona: persona,
      transcript: transcript,
      text: synthesisText,
      scenarioData: scenarioData,
      track: track,
      sessionId: sessionId,
      locale: languageCode,
    );
  }

  Future<Map<String, dynamic>> correctAnalysis({
    required String scenarioId,
    required Map<String, dynamic> persona,
    required List<Map<String, String>> transcript,
    required String analysisText,
    Map<String, dynamic>? scenarioData,
    String? track,
    String? sessionId,
  }) {
    return _correctWriting(
      kind: 'analysis',
      scenarioId: scenarioId,
      persona: persona,
      transcript: transcript,
      text: analysisText,
      scenarioData: scenarioData,
      track: track,
      sessionId: sessionId,
      locale: languageCode,
    );
  }

  Future<Map<String, dynamic>> correctProfessionalWriting({
    required String kind,
    required String scenarioId,
    required Map<String, dynamic> persona,
    required String text,
    List<Map<String, String>> transcript = const [],
    Map<String, dynamic>? scenarioData,
    String? track,
    bool examMode = false,
    String? sessionId,
    String? locale,
  }) {
    return _correctWriting(
      kind: kind,
      scenarioId: scenarioId,
      persona: persona,
      transcript: transcript,
      text: text,
      scenarioData: scenarioData,
      track: track,
      examMode: examMode,
      sessionId: sessionId,
      locale: locale ?? languageCode,
    );
  }

  Future<Map<String, dynamic>> _correctWriting({
    required String kind,
    required String scenarioId,
    required Map<String, dynamic> persona,
    required List<Map<String, String>> transcript,
    required String text,
    Map<String, dynamic>? scenarioData,
    String? track,
    bool examMode = false,
    String? sessionId,
    String? locale,
  }) async {
    try {
      final result = await _functions.httpsCallable('aiCorrectWriting').call({
        'kind': kind,
        'scenarioId': scenarioId,
        'persona': persona,
        'transcript': transcript,
        'text': text,
        'scenarioData': scenarioData ?? const <String, dynamic>{},
        'track': track,
        'examMode': examMode,
        'sessionId': sessionId,
        'locale': locale ?? languageCode,
      });
      return _map(_map(result.data)['result']);
    } catch (error) {
      throw _friendlyError(error);
    }
  }
}
