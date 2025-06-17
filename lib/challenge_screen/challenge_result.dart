// lib/screens/challenge_result.dart

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../models/challenge_model.dart';
import 'challenge_home_menu.dart';
import '../rotating_glow_border.dart';
import '../gradient_text.dart';
import '../animated_gradient_button.dart';

class ChallengeResultScreen extends StatelessWidget {
  final ChallengeModel challenge;
  const ChallengeResultScreen({Key? key, required this.challenge}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tri par score décroissant puis temps ascendant
    final players = challenge.players.values.toList()
      ..sort((a, b) {
        final sc = b.score.compareTo(a.score);
        if (sc != 0) return sc;
        final ta = a.timeTaken;
        final tb = b.timeTaken;
        return ta.compareTo(tb);
      });

    // Détecte égalité parfaite du premier
    final isDraw = players.length > 1 &&
        players[0].score == players[1].score &&
        players[0].timeTaken == players[1].timeTaken;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.deepPurple.shade300, Colors.indigo.shade700],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Animation Lottie centrée
              if (!isDraw)
                Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Lottie.network(
                      'https://assets2.lottiefiles.com/packages/lf20_touohxv0.json',
                      repeat: false,
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Titre gradient centré
              Center(
                child: GradientText(
                  '🏁 Résultats du Défi 🏁',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  gradient: const LinearGradient(colors: [Colors.amber, Colors.orangeAccent]),
                ),
              ),

              const SizedBox(height: 24),

              // Carte du gagnant
              RotatingGlowBorder(
                borderWidth: 3,
                borderRadius: 12,
                colors: [Colors.cyanAccent, Colors.white, Colors.deepOrangeAccent],
                duration: const Duration(seconds: 5),
                child: Card(
                  color: Colors.amber.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    child: Column(
                      children: [
                        AutoSizeText(
                          isDraw ? '⚖️ Égalité parfaite !' : '🎉 Grand Gagnant 🎉',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        GradientText(
                          players.first.name,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                          gradient: const LinearGradient(
                            colors: [Colors.purpleAccent, Colors.deepPurple],
                          ),
                        ),
                        const SizedBox(height: 8),
                        AutoSizeText(
                          '${players.first.score} pts',
                          style: const TextStyle(fontSize: 18, color: Colors.black54),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sous-titre centré
              Center(
                child: AutoSizeText(
                  'Classement des joueurs :',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 12),

              // Liste du classement
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: players.length,
                  itemBuilder: (ctx, idx) {
                    final p = players[idx];
                    IconData icon;
                    Color iconColor, cardColor;
                    if (idx == 0) {
                      icon = Icons.emoji_events;
                      iconColor = Colors.amber;
                      cardColor = Colors.amber.shade100;
                    } else if (idx == 1) {
                      icon = Icons.military_tech;
                      iconColor = Colors.grey;
                      cardColor = Colors.grey.shade200;
                    } else {
                      icon = Icons.grade;
                      iconColor = Colors.brown;
                      cardColor = Colors.brown.shade100;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Card(
                        color: cardColor,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: Icon(icon, color: iconColor),
                          title: GradientText(
                            p.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.indigo]),
                          ),
                          subtitle: AutoSizeText(
                            'Temps : ${(p.timeTaken! / 1000).toStringAsFixed(2)} s',
                            style: const TextStyle(color: Colors.white70),
                            maxLines: 1,
                            textAlign: TextAlign.left,
                          ),
                          trailing: AutoSizeText(
                            '${p.score} pts',
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                            maxLines: 1,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Bouton retour centré
              Center(
                child: AnimatedGradientButton(
                  child: const AutoSizeText(
                    "Retour à l'accueil",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const ChallengeHomeMenu()),
                          (route) => false,
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
