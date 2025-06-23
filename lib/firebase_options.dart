import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
            'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC0ygxn9vmbe2LE0akV-sQDdfFS4C1FGrg',
    appId: '1:163745254135:android:ff4915f8ef3afd493461f2',
    messagingSenderId: '163745254135',
    projectId: 'quiz-commercial',
    storageBucket: 'quiz-commercial.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAPYfiUGMN-2ZpcqDax3VoQArcesFy4mPE',
    appId: '1:163745254135:ios:349c87d8e346624e3461f2',
    messagingSenderId: '163745254135',
    projectId: 'quiz-commercial',
    storageBucket: 'quiz-commercial.appspot.com',
    iosBundleId: 'com.quizcommercial2024.quizCommercial2024',
  );
}

