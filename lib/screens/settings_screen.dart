
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../drawer/custom_bottom_nav_bar.dart';
import '../logo_widget.dart';



class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool showExplanation = true;
  bool soundEnabled = true;
  void _rateApp() async {
    final url = 'https://play.google.com/store/apps/details?id=com.quiz_commercial2024.quiz_commercial2024&pcampaignid=web_share';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      // Gérer l'erreur si l'URL ne peut pas être lancée
      print('Could not launch $url');
    }
  }

  void _shareApp() {
    Share.share(
        'Découvrez cette superbe application: [https://play.google.com/store/apps/details?id=com.quiz_commercial2024.quiz_commercial2024&pcampaignid=web_share]'.tr(),
        subject: 'Partager avec'.tr());
  }

  void _showLanguagePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Choisir la langue".tr()),
          content: SingleChildScrollView( // Ajouté pour gérer les contenus dépassant la hauteur
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Wrap(  // Utiliser un Wrap au lieu d'une Row pour une meilleure réactivité
                  spacing: 10, // Espace horizontal entre les chips
                  alignment: WrapAlignment.center, // Centrer les chips
                  children: [
                    InkWell(
                      onTap: () {
                        context.setLocale(Locale('fr'));
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        margin: EdgeInsets.all(8), // Ajustement de l'espace autour du bouton
                        padding: EdgeInsets.all(8), // Augmente la zone cliquable
                        decoration: BoxDecoration(
                          color: Colors.white, // Ajoute une couleur de fond
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5), // Ajoute une ombre
                              spreadRadius: 3,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(20), // Arrondit les coins
                        ),
                        child: Image.asset('assets/images/france.png', width: 28, height: 28),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        context.setLocale(Locale('en'));
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        margin: EdgeInsets.all(8), // Ajustement de l'espace autour du bouton
                        padding: EdgeInsets.all(8), // Augmente la zone cliquable
                        decoration: BoxDecoration(
                          color: Colors.white, // Ajoute une couleur de fond
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5), // Ajoute une ombre
                              spreadRadius: 3,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(20), // Arrondit les coins
                        ),
                        child: Image.asset('assets/images/united-kingdom.png', width: 28, height: 28),
                      ),
                    ),
                    // Ajoutez d'autres langues ici
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
          return const CircularProgressIndicator();
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
                mainAxisAlignment: MainAxisAlignment.center,
                // Centrer les éléments verticalement
                children: [
                  SizedBox(height: 40),
                  // Espacement entre le haut de l'écran et le logo
                  LogoWidget(),

                  QrImageView(
                    data: "https://play.google.com/store/apps/details?id=com.quiz_commercial2024.quiz_commercial2024&pcampaignid=web_share",
                    version: QrVersions.auto,
                    size: 120.0,
                    // ignore: deprecated_member_use
                    foregroundColor: Colors.blue.shade800, // Couleur du QR code
                  ),
                  Text(
                    "Scanne moi",
                    style: TextStyle(
                      color: Colors.blue.shade800, // Couleur du texte
                      fontSize: 14, // Taille du texte
                    ),
                  ),
                  SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.check, color: Colors.black87),
                    title: const Text('Afficher Explication (Quizz)'),
                    trailing: Switch(
                      value: showExplanation,
                      onChanged: (value) async {
                        setState(() {
                          showExplanation = value;
                        });
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setBool('showExplanation', value);
                      },
                    ),
                  ),
                  ListTile(
                    leading:  Icon(Icons.volume_up, color: Colors.green.shade300),
                    title: const Text('Activer le son'),
                    trailing: Switch(
                      value: soundEnabled,
                      onChanged: (value) async {
                        setState(() {
                          soundEnabled = value;
                        });
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setBool('soundEnabled', value);
                      },
                    ),
                  ),
                  buildStepButton(

                    Icons.info,
                    "Information".tr(),
                        () {
                      Navigator.pushNamed(context, '/information');
                    },
                    Colors.blue.shade800, // Couleur de l'icône
                    true, // Rendre le bouton cliquable
                  ),

                  buildStepButton(

                    Icons.help_outline,
                    "À propos".tr(),
                        () {
                      Navigator.pushNamed(context, '/about');
                    },
                    Colors.blue.shade800, // Couleur de l'icône
                    true, // Rendre le bouton cliquable
                  ),

                  buildLanguageSelectionButton(),
                  buildStepButton(

                    Icons.star,
                    "Noter l'application".tr(),
                    _rateApp,
                    Colors.blue.shade800, // Couleur de l'icône
                    true, // Rendre le bouton cliquable
                  ),
                  buildStepButton(

                    Icons.share,
                    "Partager l'application".tr(),
                    _shareApp,
                    Colors.blue.shade800, // Couleur de l'icône
                    true, // Rendre le bouton cliquable
                  ),




                  buildStepButton(

                    Icons.exit_to_app,
                    "Se déconnecter".tr(),
                        () async {
                      await FirebaseAuth.instance.signOut();
                      // Redirigez vers l'écran de connexion après la déconnexion
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    Colors.black, // Couleur de l'icône
                    true, // Rendre le bouton cliquable
                  ),

                  buildStepButton(

                    Icons.delete_forever,
                    "Supprimer le compte".tr(),
                        () => _showDeleteAccountDialog(context),
                    Colors.black, // Couleur de l'icône
                    true, // Rendre le bouton cliquable
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Tous droits réservés © 2023".tr(),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    "Conforme au RGPD de l'UE".tr(),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          bottomNavigationBar: CustomBottomNavBar(
            parentContext: context,
            currentIndex: 4,
            scaffoldKey: _scaffoldKey,
             // Adaptez les paramètres en fonction des besoins
          ),
        );
      },
    );
  }
  Widget buildLanguageSelectionButton() {
    return GestureDetector(
      onTap: () => _showLanguagePicker(context),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        width: MediaQuery.of(context).size.width * 0.7, // Définir la largeur du bouton
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.3), // Modifiez la couleur selon le thème de l'application
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.language, // Icône de langue
                color: Colors.blue.shade800, // Modifiez la couleur selon le thème de l'application
                size: 25,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Choisir la langue".tr(), // Texte à changer selon la langue actuelle de l'app ou vos préférences
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800, // Modifiez la couleur selon le thème de l'application
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // Fonction buildStepButton
  Widget buildStepButton(IconData icon, String text, Function() onPressed,
      Color iconColor, bool isClickable) {
    return GestureDetector(
      onTap: isClickable ? onPressed : null,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isClickable ? Colors.grey.shade200 : Colors.blueAccent.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        width: MediaQuery.of(context).size.width * 0.7, // Définir la largeur du bouton
        // Utilisez MediaQuery.of(context).size.width * pour calculer une largeur proportionnelle
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 25,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Supprimer le compte'.tr()),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer définitivement votre compte ? Cette action est irréversible.'.tr()),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'.tr()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Supprimer'.tr(), style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop(); // Ferme la boîte de dialogue
                try {
                  await FirebaseAuth.instance.currentUser?.delete();
                  Navigator.of(context).pushReplacementNamed('/login');
                  // Redirection vers l'écran de connexion
                } catch (e) {
                  // Gérer les erreurs ici
                  print("Erreur lors de la suppression du compte: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }
