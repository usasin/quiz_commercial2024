import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> sendToServer(File audioFile) async {
  var request = http.MultipartRequest(
      'POST', Uri.parse('http://192.168.1.98:5000/transcribe_and_respond')
  );
  request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

  var response = await request.send();

  if (response.statusCode == 200) {
    String responseText = await response.stream.bytesToString();
    print("Réponse de GPT : $responseText");
  } else {
    print("Erreur : ${response.statusCode}");
  }
}
