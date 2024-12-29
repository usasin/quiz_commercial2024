import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Initialiser le service de notification
  init() {
    _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Gérer la réception des notifications lorsque l'application est en premier plan
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Gérer le tap sur la notification
    });
  }

  // Obtenir le token FCM pour l'utilisateur
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

// Autres méthodes pour gérer des cas spécifiques...
}
