import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

import '../logo_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscured = true;
  bool _rememberMe = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
    _loadLoginInfo();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isObscured = !_isObscured;
    });
  }

  Future<void> _checkAuthenticationStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      Navigator.pushNamed(context, '/levels');
    }
  }

  Future<void> _loadLoginInfo() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = (prefs.getString('email') ?? '');
      _passwordController.text = (prefs.getString('password') ?? '');
      _rememberMe = (prefs.getBool('rememberMe') ?? false);
    });
  }

  Future<void> _saveLoginInfo() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('email', _emailController.text);
    prefs.setString('password', _passwordController.text);
    prefs.setBool('rememberMe', _rememberMe);
  }

  Future<void> _signIn() async {
    try {
      if (_rememberMe) {
        _saveLoginInfo();
      }
      Navigator.pushNamed(context, '/levels');
    } on FirebaseAuthException catch (e) {
      print('Erreur Firebase Auth: ${e.message}');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message!).tr()));
    } catch (e) {
      print('Erreur inconnue: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Une erreur s\'est produite'.tr())));
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final UserCredential userCredential =
        await _auth.signInWithCredential(credential);

        final User? user = userCredential.user;

        if (user != null) {
          if (userCredential.additionalUserInfo!.isNewUser) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
              'name': user.displayName,
              'email': user.email,
              'photoURL': user.photoURL,
              'totalScore': 0,
              'unlockedLevels': 1,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          if (_rememberMe) {
            _saveLoginInfo();
          }
          Navigator.pushNamed(context, '/levels');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion avec Google: $e')),
      );
    }
  }

  void _changeLanguage(String languageCode) {
    context.setLocale(Locale(languageCode));
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(
      context,
      designSize: const Size(414, 896),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.teal.shade50,
                  Colors.white,
                  Colors.teal.shade50,
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(height: 80.0.h),
                  const LogoWidget(),
                  SizedBox(height:40.0.h),
                  Text(
                    'connexion'.tr(),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLanguageSwitch('fr', 'assets/images/france.png'),
                      _buildLanguageSwitch('en', 'assets/images/united-kingdom.png'),
                    ],
                  ),
                  SizedBox(height:40.0.h),
                  _buildTextField(_emailController, 'Email'.tr()),
                  SizedBox(height: 16.h),
                  _buildPasswordField(),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 65.0.w, vertical: 10.0.h),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (bool? value) {
                            setState(() {
                              _rememberMe = value!;
                            });
                          },
                        ),
                        Text("Se souvenir de moi").tr(),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: _buildSignInButton(),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: _buildGoogleSignInButton(),
                  ),
                  TextButton(
                    onPressed: () {
                      _showForgotPasswordDialog(context);
                    },
                    child: Text(
                      'Mot de passe oublié'.tr(),
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  SizedBox(height:80.0.h),

                  // Bas de page avec "Tous droits réservés"
                  Padding(
                    padding: EdgeInsets.only(bottom: 20.0.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Tous droits réservés © 2023".tr(),
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 12.sp,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4.0.h),
                        Text(
                          "Conforme au RGPD de l'UE".tr(),
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12.sp,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        filled: true,
        fillColor: Colors.brown.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      style: const TextStyle(color: Colors.black),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value!.isEmpty) {
          return 'Veuillez entrer votre email'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: 'Mot de passe'.tr(),
        filled: true,
        fillColor: Colors.brown.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isObscured ? Icons.visibility : Icons.visibility_off,
            color: Colors.black87,
          ),
          onPressed: _togglePasswordVisibility,
        ),
      ),
      style: const TextStyle(color: Colors.black),
      obscureText: _isObscured,
      validator: (value) {
        if (value!.isEmpty) {
          return 'Veuillez entrer votre mot de passe'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildSignInButton() {
    return ElevatedButton(
      onPressed: _signIn,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ads_click_rounded),
          SizedBox(width: 8.w),
          Text('Valider'.tr()),
        ],
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return ElevatedButton.icon(
      icon: SvgPicture.asset(
        'assets/icons/Google.svg',
        width: 24.w,
        height: 24.h,
      ),
      label: Text('Se connecter avec Google'.tr()),
      onPressed: _signInWithGoogle,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildLanguageSwitch(String langCode, String imagePath) {
    return InkWell(
      onTap: () {
        _changeLanguage(langCode);
      },
      child: Container(
        margin: EdgeInsets.all(10.w),
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 3,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Image.asset(imagePath, width: 28.w, height: 28.h),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController _emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Réinitialiser le mot de passe'.tr()),
          content: TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(color: Colors.black),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'.tr()),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: _emailController.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Email de réinitialisation de mot de passe envoyé à ${_emailController.text}',
                    ),
                  ),
                );
                Navigator.of(context).pop();
              },
              child: Text('Envoyer'.tr()),
            ),
          ],
        );
      },
    );
  }
}
