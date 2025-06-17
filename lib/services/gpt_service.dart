// fichier gpt_service.dart (mis à jour avec transcription et synthèse vocale GPT-4o)
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class GptService {
  final String _apiKey = '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';

  /// Génération de texte avec modèle GPT-4o-mini
  Future<String> generateTextBasedOnSalesScript(
      List<Map<String, dynamic>> messages,
      String? salesScript, {
        String model = 'gpt-4o-mini',
        double temperature = 1.0,
        int maxTokens = 256,
      }) async {
    if (salesScript != null && salesScript.isNotEmpty) {
      messages.insert(0, {
        'role': 'system',
        'content': 'Script de vente généré: $salesScript',
      });
    }
    return generateText(messages, model: model, temperature: temperature, maxTokens: maxTokens);
  }

  Future<String> generateText(
      List<Map<String, dynamic>> messages, {
        String model = 'gpt-4o-mini',
        double temperature = 1.0,
        int maxTokens = 256,
      }) async {
    final response = await _sendRequest(messages, model, temperature, maxTokens);
    return _extractResponse(response);
  }

  Future<http.Response> _sendRequest(
      List<Map<String, dynamic>> messages,
      String model,
      double temperature,
      int maxTokens,
      ) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode == 200) {
        return response;
      } else {
        throw Exception('Erreur API GPT: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur requête API GPT: $e');
    }
  }

  String _extractResponse(http.Response response) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['choices'][0]['message']['content'].trim();
  }

  /// Transcription audio via GPT-4o
  /*───────────────── TRANSCRIPTION ───────────────*/
  Future<String> transcribeAudio(File file) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
    )

    // 1️⃣ d’abord le fichier
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: 'speech.m4a',
        contentType: MediaType('audio', 'm4a'),
      ))

    // 2️⃣ puis les champs « text/plain »
      ..fields['model']    = 'whisper-1'
      ..fields['language'] = 'fr'
      ..fields['response_format'] = 'json'

    // 3️⃣ et SEULEMENT APRÈS on ajoute les headers
      ..headers['Authorization'] = 'Bearer $_apiKey';

    final res  = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode != 200) throw 'Whisper ${res.statusCode} – $body';
    return jsonDecode(body)['text'].trim();
  }


  /// Synthèse vocale via GPT-4o-mini-tts
  Future<File> synthesizeSpeech(String text, {String voice = 'alloy', double speed = 1.0}) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/audio/speech'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini-tts',
        'input': text,
        'voice': voice,
        'speed': speed,
      }),
    );

    if (response.statusCode == 200) {
      final audioBytes = response.bodyBytes;
      final audioFile = File('${Directory.systemTemp.path}/response.mp3');
      await audioFile.writeAsBytes(audioBytes);
      return audioFile;
    } else {
      throw Exception('Erreur synthèse vocale: ${response.statusCode} - ${response.body}');
    }
  }

  /// Fetch sales script from Firestore
  Future<String> fetchSalesScriptFromFirestore(String documentId) async {
    var document = await FirebaseFirestore.instance.collection('salesScripts').doc(documentId).get();
    if (document.exists) {
      return document.data()?['scriptText'] ?? '';
    } else {
      throw Exception('Script de vente non trouvé');
    }
  }
}
