import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieWidget extends StatelessWidget {
  final String animationPath;

  LottieWidget({required this.animationPath});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseStorage.instance
          .ref(animationPath)
          .getDownloadURL(),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        } else {
          if (snapshot.error != null) {
            return const SizedBox.shrink();
          } else {
            return Lottie.network(
              snapshot.data!,
              fit: BoxFit.cover,
            );
          }
        }
      },
    );
  }
}
