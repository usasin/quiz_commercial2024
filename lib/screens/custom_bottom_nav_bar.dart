import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// 🎨 Palette CIP
const cipBlue = Color(0xFF5AACDB);
const cipGreen = Color(0xFF3CC398);
const cipPeach = Color(0xFFFBA49B);

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    String route;
    switch (index) {
      case 0:
        route = '/levels'; // Accueil / Parcours
        break;
      case 1:
        route = '/toolbox'; // Outils (Boîte à outils)
        break;
      case 2:
        route = '/profile'; // Profil
        break;
      default:
        route = '/levels';
    }

    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              currentIndex: currentIndex,
              onTap: (i) => _onTap(context, i),
              selectedItemColor: cipBlue,
              unselectedItemColor: Colors.grey.shade500,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 11,
              ),
              showUnselectedLabels: true,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(
                    currentIndex == 0
                        ? Icons.flag_rounded
                        : Icons.flag_outlined,
                  ),
                  label: 'nav.levels'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    currentIndex == 1
                        ? Icons.widgets_rounded
                        : Icons.widgets_outlined,
                  ),
                  label: 'nav.toolbox'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    currentIndex == 2
                        ? Icons.person_rounded
                        : Icons.person_outline_rounded,
                  ),
                  label: 'nav.profile'.tr(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
