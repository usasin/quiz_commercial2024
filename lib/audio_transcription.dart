import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioTranscriptionApp extends StatefulWidget {
  @override
  _AudioTranscriptionAppState createState() => _AudioTranscriptionAppState();
}

class _AudioTranscriptionAppState extends State<AudioTranscriptionApp> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool isRecorderInitialized = false;
  bool isRecording = false;
  String? localFilePath;
  String? audioUrl;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    try {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException('Permission Micro refusée');
      }

      await _recorder.openRecorder();
      setState(() {
        isRecorderInitialized = true;
      });
      print('Enregistreur initialisé avec succès.');
    } catch (e) {
      print('Erreur lors de l\'initialisation de l\'enregistreur : $e');
    }
  }

  Future<void> startRecording() async {
    if (!isRecorderInitialized) {
      print('Enregistreur non initialisé.');
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      localFilePath = '${directory.path}/audio_record.aac';

      await _recorder.startRecorder(
        toFile: localFilePath,
        codec: Codec.aacADTS,
      );

      setState(() {
        isRecording = true;
      });
      print('Enregistrement démarré...');
    } catch (e) {
      print('Erreur lors du démarrage de l\'enregistrement : $e');
    }
  }

  Future<void> stopRecording() async {
    if (!isRecording) {
      print('Aucun enregistrement en cours.');
      return;
    }

    try {
      await _recorder.stopRecorder();
      setState(() {
        isRecording = false;
      });
      print('Enregistrement arrêté. Fichier local : $localFilePath');

      // Étape 2 : Télécharger sur Firebase
      await uploadAudioToFirebase();
    } catch (e) {
      print('Erreur lors de l\'arrêt de l\'enregistrement : $e');
    }
  }

  Future<void> uploadAudioToFirebase() async {
    if (localFilePath == null || !File(localFilePath!).existsSync()) {
      print('Fichier audio introuvable. Assurez-vous que l\'enregistrement est terminé.');
      return;
    }

    try {
      final file = File(localFilePath!);
      final storageRef = FirebaseStorage.instance.ref().child('audios/${file.path.split('/').last}');
      final uploadTask = storageRef.putFile(file);

      await uploadTask.whenComplete(() => {});
      audioUrl = await storageRef.getDownloadURL();
      print('Audio téléchargé sur Firebase. URL : $audioUrl');

      // Étape 3 : Transcrire l'audio (Simulation ici)
      await transcribeAudio();
    } catch (e) {
      print('Erreur lors du téléchargement de l\'audio sur Firebase : $e');
    }
  }

  Future<void> transcribeAudio() async {
    if (audioUrl == null || audioUrl!.isEmpty) {
      print('Aucun URL audio disponible. Assurez-vous que l\'audio a été téléchargé.');
      return;
    }

    try {
      print('Commencer la transcription pour l\'audio : $audioUrl');
      // Simuler une transcription
      String transcription = 'Texte simulé de transcription de l\'audio.';

      // Étape 4 : Réponse simulée
      print('Transcription : $transcription');
    } catch (e) {
      print('Erreur lors de la transcription de l\'audio : $e');
    }
  }

  @override
  void dispose() {
    if (_recorder.isRecording) {
      _recorder.stopRecorder();
    }
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Transcription avec GPT'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isRecording ? stopRecording : startRecording,
              child: Text(isRecording ? 'Arrêter l\'enregistrement' : 'Démarrer l\'enregistrement'),
            ),
          ],
        ),
      ),
    );
  }
}
