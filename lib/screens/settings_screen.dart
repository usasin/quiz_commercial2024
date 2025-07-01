// lib/settings_screen.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../animated_gradient_button.dart';
import '../gradient_text.dart';

import '../drawer/custom_bottom_nav_bar.dart';


class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool showExplanation = true;
  bool soundEnabled = true;

  
  void _showLanguagePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Choisir la langue".tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Wrap(
                  spacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    InkWell(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('languageCode', 'fr');
                        context.setLocale(Locale('fr'));
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 3,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Image.asset(
                          'assets/images/france.png',
                          width: 28,
                          height: 28,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('languageCode', 'en');
                        context.setLocale(Locale('en'));
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 3,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Image.asset(
                          'assets/images/united-kingdom.png',
                          width: 28,
                          height: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final prefs = snapshot.data!;
        showExplanation = prefs.getBool('showExplanation') ?? true;
        soundEnabled = prefs.getBool('soundEnabled') ?? true;

        return Scaffold(
          key: _scaffoldKey,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white70,
                  Colors.white24,
                  Colors.white,
                  Colors.white54,
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo animée


                  const SizedBox(height: 24),
                  // Titre "Paramètres" en GradientText
                  GradientText(
                    'Paramètres'.tr(),
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                    gradient:  LinearGradient(colors: [
                      Colors.blue.shade900,
                      Colors.white,
                      Colors.blue.shade900,
                    ]),
                  ),

                  const SizedBox(height: 24),
                 
                  
                  // Toggle: Afficher Explication
                  ListTile(
                    leading: Icon(Icons.check,
                        color: showExplanation ? Colors.green : Colors.grey),
                    title: Text('Afficher Explication (Quizz)'.tr()),
                    trailing: Switch(
                      value: showExplanation,
                      onChanged: (value) async {
                        setState(() => showExplanation = value);
                        prefs.setBool('showExplanation', value);
                      },
                      activeColor: Colors.blue.shade900,
                    ),
                  ),

                  // Toggle: Activer le son
                  ListTile(
                    leading: Icon(Icons.volume_up,
                        color: soundEnabled ? Colors.green.shade300 : Colors.grey),
                    title: Text('Activer le son'.tr()),
                    trailing: Switch(
                      value: soundEnabled,
                      onChanged: (value) async {
                        setState(() => soundEnabled = value);
                        prefs.setBool('soundEnabled', value);
                      },
                      activeColor: Colors.blue.shade900,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Boutons animés
                  AnimatedGradientButton(
                    onTap: () {
                      Navigator.pushNamed(context, '/information');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          "Information".tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  AnimatedGradientButton(
                    onTap: () {
                      Navigator.pushNamed(context, '/about');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.help_outline, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          "À propos".tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  AnimatedGradientButton(
                    onTap: () => _showLanguagePicker(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.language, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          "Choisir la langue".tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  
                
                 

                  const SizedBox(height: 12),
                  AnimatedGradientButton(
                    onTap: () => _showDeleteAccountDialog(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_forever, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          "Supprimer le compte".tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    "Tous droits réservés © 2025".tr(),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    "Conforme au RGPD de l'UE".tr(),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          bottomNavigationBar: CustomBottomNavBar(
            parentContext: context,
            currentIndex: 4,
            scaffoldKey: _scaffoldKey,
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Supprimer le compte'.tr()),
          content: Text(
            'Êtes-vous sûr de vouloir supprimer définitivement votre compte ? '
                'Cette action est irréversible.'.tr(),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'.tr()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Supprimer'.tr(),
                  style: const TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseAuth.instance.currentUser?.delete();
                  Navigator.of(context).pushReplacementNamed('/login');
                } catch (e) {
                  print("Erreur lors de la suppression du compte: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }
}

