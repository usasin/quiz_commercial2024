import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/levels_page.dart';
import 'services/page_route_builder.dart';

class CongratulationsPage extends StatefulWidget {
  final int score;
  final int level;
  final Color levelColor;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String firestoreCollectionId;

  const CongratulationsPage({
    Key? key,
    required this.score,
    required this.level,
    required this.levelColor,
    required this.scaffoldKey,
    required this.firestoreCollectionId,
  }) : super(key: key);

  @override
  _CongratulationsPageState createState() => _CongratulationsPageState();
}

class _CongratulationsPageState extends State<CongratulationsPage> {
  late VideoPlayerController _controller;

  String get videoPath {
    if (widget.score >= 100) return 'assets/videos/video_for_100.mp4';
    if (widget.score >= 90) return 'assets/videos/video_for_90.mp4';
    return 'assets/videos/video_for_80.mp4';
  }

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(videoPath)
      ..initialize().then((_) {
        _controller.play();
        setState(() {});
      });

    // Laissez la vidéo se jouer pendant 5 secondes puis redirigez
    Future.delayed(Duration(seconds: 7), () async {
      // Sauvegarder le dernier chapitre et niveau joué
      await saveLastPlayed(widget.firestoreCollectionId, widget.level);

      // Rediriger vers la page des niveaux
      Navigator.of(context).pushReplacement(customPageRoute(LevelsPage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        )
            : CircularProgressIndicator(),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  // Fonction pour sauvegarder le dernier chapitre et niveau joué
  Future<void> saveLastPlayed(String chapterId, int level) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastPlayedChapter', chapterId);
    await prefs.setInt('lastPlayedLevel', level);
  }
}
