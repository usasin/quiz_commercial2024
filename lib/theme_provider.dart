import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _darkTheme = false;

  bool get darkTheme => _darkTheme;

  void toggleTheme() {
    _darkTheme = !_darkTheme;
    notifyListeners();
  }

  // Thème clair personnalisé
  ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: Colors.orangeAccent, // Couleur principale
        secondary: Colors.orange, // Couleur d'accentuation
      ),
      scaffoldBackgroundColor: Colors.white, // Fond de l'application
      cardColor: Colors.white, // Couleur des cartes
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black87),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.brown.shade100, // Couleur des boutons
          foregroundColor: Colors.white, // Couleur du texte du bouton
        ),
      ),
    );
  }

  // Thème sombre personnalisé
  ThemeData get darkThemeData {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Colors.orangeAccent, // Couleur principale
        secondary: Colors.orangeAccent, // Couleur d'accentuation
      ),
      scaffoldBackgroundColor: Colors.black, // Fond de l'application
      cardColor: Colors.grey.shade800, // Couleur des cartes
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey, // Couleur des boutons
          foregroundColor: Colors.white, // Couleur du texte du bouton
        ),
      ),
    );
  }

  ThemeData get currentTheme => _darkTheme ? darkThemeData : lightTheme;
}
