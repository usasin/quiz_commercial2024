// fichier gpt_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:http/http.dart' as http;

class GptService {
  final String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  final String _apiKey = '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';


  Future<String> generateTextBasedOnSalesScript(List<Map<String, dynamic>> messages, String? salesScript) async {
    if (salesScript != null && salesScript.isNotEmpty) {
      messages.insert(0, {
        'role': 'system',
        'content': 'Script de vente généré: $salesScript'
      });
    }
    return generateText(messages);
  }

  Future<String> generateText(List<Map<String, dynamic>> messages) async {
    final response = await _sendRequest(messages);
    return _extractResponse(response);
  }

  Future<http.Response> _sendRequest(List<Map<String, dynamic>> messages) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        return response;
      } else {
        throw Exception('Erreur API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur lors de la requête à l\'API: $e');
    }
  }

  String _extractResponse(http.Response response) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['choices'][0]['message']['content'].trim();
  }

  Future<String> fetchSalesScriptFromFirestore(String documentId) async {
    var document = await FirebaseFirestore.instance.collection('salesScripts').doc(documentId).get();
    if (document.exists) {
      return document.data()?['scriptText'] ?? '';
    } else {
      throw Exception('Script de vente non trouvé');
    }
  }
}