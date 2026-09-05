import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';

/// Audio sécurisé via Firebase Functions.
/// Le nom historique est conservé pour éviter de casser les écrans V1.
class GptService {
  GptService({this.languageCode = 'fr'});

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
              fr: 'Connecte-toi pour utiliser la simulation vocale.',
              en: 'Sign in to use the voice simulation.',
            ),
          );
        case 'resource-exhausted':
          return Exception(
            _t(
              fr: 'Ta séance est complète. Relis les conseils du coach avant le prochain essai.',
              en: 'Your session is complete. Review the coach feedback before your next attempt.',
            ),
          );
        case 'deadline-exceeded':
          return Exception(
            _t(
              fr: 'Le service audio met trop de temps à répondre. Réessaie.',
              en: 'The audio service is taking too long. Try again.',
            ),
          );
        case 'unavailable':
        case 'failed-precondition':
          return Exception(
            _t(
              fr: 'Service audio temporairement indisponible.',
              en: 'Audio service temporarily unavailable.',
            ),
          );
      }
      return Exception(
        error.message ??
            _t(
              fr: 'Service audio indisponible.',
              en: 'Audio service unavailable.',
            ),
      );
    }
    if (error is Exception) return error;
    return Exception(
      _t(fr: 'Service audio indisponible.', en: 'Audio service unavailable.'),
    );
  }

  Future<String> transcribeAudio(
    File file, {
    bool examMode = false,
    String? sessionId,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        throw Exception(
          _t(
            fr: 'Enregistrement trop long. Réessaie avec une réponse plus courte.',
            en: 'Recording too long. Try again with a shorter response.',
          ),
        );
      }
      final result = await _functions
          .httpsCallable(
            'aiTranscribe',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
          )
          .call({
            'audioBase64': base64Encode(bytes),
            'mimeType': 'audio/mp4',
            'examMode': examMode,
            'sessionId': sessionId,
            'locale': languageCode,
          });
      final text = (_map(result.data)['text'] ?? '').toString().trim();
      if (text.isEmpty) {
        throw Exception(
          _t(fr: 'Aucune parole reconnue.', en: 'No speech was recognized.'),
        );
      }
      return text;
    } catch (error) {
      throw _friendlyError(error);
    }
  }

  Future<File> synthesizeSpeech(
    String text, {
    String voice = 'alloy',
    double speed = 1.0,
    bool examMode = false,
  }) async {
    try {
      final result = await _functions.httpsCallable('aiSpeech').call({
        'text': text,
        'voice': voice,
        'speed': speed,
        'examMode': examMode,
        'locale': languageCode,
      });
      final encoded = (_map(result.data)['audioBase64'] ?? '').toString();
      if (encoded.isEmpty) {
        throw Exception(_t(fr: 'Audio vide.', en: 'Empty audio response.'));
      }
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/cip_speech_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await file.writeAsBytes(base64Decode(encoded), flush: true);
      return file;
    } catch (error) {
      throw _friendlyError(error);
    }
  }
}
