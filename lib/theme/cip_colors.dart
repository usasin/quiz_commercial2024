import 'package:flutter/material.dart';

class CipColors {
  // Branding (inchangé)
  static const blue = Color(0xFF5AACDB);
  static const green = Color(0xFF3CC398);
  static const peach = Color(0xFFFBA49B);
  static const dark = Color(0xFF0F172A);

  // ✅ Ambiance "digital" (fond)
  static const digitalBgTop = Color(0xFFF6FAFF);     // bleu très clair
  static const digitalBgBottom = Color(0xFFF2F5FF);  // bleu/gris clair
  static const background = digitalBgTop;

  // Surfaces
  static const surface = Colors.white;
  static const surface2 = Color(0xFFF8FAFC); // surface légère (cartes secondaires)
  static const border = Color(0xFFE2E8F0);

  // Textes
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);

  // Accent discret
  static const pinkSoft = Color(0xFFF472B6);

  // Gradient marque (pour badges / hero)
  static const gradient = LinearGradient(
    colors: [blue, green, peach],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ✅ Gradient de fond digital (à utiliser dans les pages)
  static const digitalGradient = LinearGradient(
    colors: [digitalBgTop, digitalBgBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// Aliases (compatibilité)
const cipBlue = CipColors.blue;
const cipGreen = CipColors.green;
const cipPeach = CipColors.peach;
const cipDark = CipColors.dark;
