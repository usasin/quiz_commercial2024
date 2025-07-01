// lib/settings_screen.dart
// ignore_for_file: use_build_context_synchronously, avoid_print
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';          // ← reste pour Android
import 'package:qr_flutter/qr_flutter.dart';             // ← reste pr. Android
import 'package:share_plus/share_plus.dart';             // ← reste pr. Android

import '../animated_gradient_button.dart';
import '../gradient_text.dart';
import '../rotating_glow_border.dart';
import '../drawer/custom_bottom_nav_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool showExplanation = true;
  bool soundEnabled = true;

  // ——————————————————— actions Android seulement
  void _rateApp() async {
    const url =
        'https://play.google.com/store/apps/details?id=com.quiz_commercial2024.quiz_commercial2024';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    }
  }

  void _shareApp() {
    Share.share(
      'Découvrez cette superbe application:\n'
      'https://play.google.com/store/apps/details?id=com.quiz_commercial2024.quiz_commercial2024',
      subject: 'Partager avec'.tr(),
    );
  }

  // ——————————————————— picker langue
  Future<void> _showLanguagePicker(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Choisir la langue".tr()),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _flag('fr', 'assets/images/france.png', prefs),
            _flag('en', 'assets/images/united-kingdom.png', prefs),
          ],
        ),
      ),
    );
  }

  Widget _flag(String code, String path, SharedPreferences prefs) {
    return InkWell(
      onTap: () async {
        await prefs.setString('languageCode', code);
        context.setLocale(Locale(code));
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(.5),
                blurRadius: 5,
                offset: const Offset(0, 3))
          ],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Image.asset(path, width: 28, height: 28),
      ),
    );
  }

  // ——————————————————— UI
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isIOS = Platform.isIOS;

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final prefs = snap.data!;
        showExplanation = prefs.getBool('showExplanation') ?? true;
        soundEnabled    = prefs.getBool('soundEnabled') ?? true;

        // gradient bleu-blanc-bleu demandé
        final btnGradient = [
          Colors.blue.shade800,
          Colors.white,
          Colors.blue.shade800,
        ];

        return Scaffold(
          key: _scaffoldKey,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white70, Colors.white24])),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 50),

                  // Titre
                  GradientText(
                    'Paramètres'.tr(),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    gradient: LinearGradient(colors: btnGradient),
                  ),

                  const SizedBox(height: 20),

                  // QR CODE + halo  (⚠️ Android seulement)
                  if (!isIOS)
                    RotatingGlowBorder(
                      borderWidth: 4,
                      borderRadius: 12,
                      colors: btnGradient,
                      duration: const Duration(seconds: 4),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(.1),
                                blurRadius: 6,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: "https://play.google.com/store/apps/details?id=com.quiz_commercial2024.quiz_commercial2024",
                              version: QrVersions.auto,
                              size: 140,
                              foregroundColor: Colors.blue.shade800,
                            ),
                            const SizedBox(height: 6),
                            Text("Scanne moi".tr(),
                                style: TextStyle(
                                    fontSize: 14, color: Colors.blue.shade800)),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  // ----- Switches
                  _switchTile(
                    icon: Icons.check,
                    active: showExplanation,
                    text: 'Afficher Explication (Quizz)'.tr(),
                    onChanged: (v) {
                      setState(() => showExplanation = v);
                      prefs.setBool('showExplanation', v);
                    },
                  ),
                  _switchTile(
                    icon: Icons.volume_up,
                    active: soundEnabled,
                    text: 'Activer le son'.tr(),
                    onChanged: (v) {
                      setState(() => soundEnabled = v);
                      prefs.setBool('soundEnabled', v);
                    },
                  ),

                  const SizedBox(height: 20),

                  // ----- BOUTONS
                  _button('Information'.tr(), Icons.info,
                      () => Navigator.pushNamed(context, '/information'),
                      gradient: btnGradient),
                  _button('À propos'.tr(), Icons.help_outline,
                      () => Navigator.pushNamed(context, '/about'),
                      gradient: btnGradient),
                  _button('Choisir la langue'.tr(), Icons.language,
                      () => _showLanguagePicker(context),
                      gradient: btnGradient),

                  if (!isIOS) ...[
                    _button('Noter l\'application'.tr(), Icons.star, _rateApp,
                        gradient: btnGradient),
                    _button('Partager l\'application'.tr(), Icons.share, _shareApp,
                        gradient: btnGradient),
                  ],

                  _button('Se déconnecter'.tr(), Icons.exit_to_app, () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, '/login');
                  }, gradient: btnGradient),

                  _button('Supprimer le compte'.tr(), Icons.delete_forever,
                      () => _showDeleteAccountDialog(context),
                      color: Colors.red, gradient: btnGradient),

                  const SizedBox(height: 30),
                  Text("Tous droits réservés © 2025",
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                  Text("Conforme au RGPD de l'UE",
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          bottomNavigationBar: CustomBottomNavBar(
            parentContext: context, currentIndex: 4, scaffoldKey: _scaffoldKey),
        );
      },
    );
  }

  // ——————————————————— helpers UI
  Widget _switchTile(
      {required IconData icon,
      required bool active,
      required String text,
      required ValueChanged<bool> onChanged}) {
    return ListTile(
      leading: Icon(icon, color: active ? Colors.green : Colors.grey),
      title: Text(text),
      trailing: Switch(
        value: active,
        onChanged: onChanged,
        activeColor: Colors.blue.shade800,
      ),
    );
  }

  Widget _button(String label, IconData icon, VoidCallback onTap,
      {Color? color, required List<Color> gradient}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
      child: AnimatedGradientButton(
        gradientColors: gradient,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color ?? Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ——————————————————— suppression compte
  void _showDeleteAccountDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Supprimer le compte'.tr()),
        content: Text('Êtes-vous sûr ? Cette action est irréversible.'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler'.tr())),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance.currentUser?.delete();
                Navigator.pushReplacementNamed(context, '/login');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')));
              }
            },
            child: Text('Supprimer'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
