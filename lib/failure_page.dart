import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'screens/levels_page.dart';
import 'services/page_route_builder.dart';

class FailurePage extends StatefulWidget {
  final int score;
  final int level;
  final String chapterId;

  FailurePage({
    required this.score,
    required this.level,
    required this.chapterId,
  });

  @override
  _FailurePageState createState() => _FailurePageState();
}

class _FailurePageState extends State<FailurePage> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/video_for_perdu.mp4')
      ..initialize().then((_) {
        // Assurez-vous que le contexte est disponible avant de montrer la vidéo.
        if (mounted) {
          setState(() {});
          _controller.play();
          _waitAndRedirect();
        }
      });
  }

  _waitAndRedirect() async {
    await Future.delayed(Duration(seconds: 7));
    Navigator.of(context).pushReplacement(customPageRoute(LevelsPage()));

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
            : Container(),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
