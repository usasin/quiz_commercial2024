import 'package:flutter/material.dart';

import '../leaderboard_page.dart';
import '../screens/lessons_screen.dart';
import '../screens/levels_page.dart';
import '../screens/profile_page.dart';
import '../screens/settings_screen.dart';

class CustomBottomNavBar extends StatefulWidget {
  final BuildContext parentContext;
  final int currentIndex;
  final GlobalKey<ScaffoldState> scaffoldKey;

  CustomBottomNavBar({
    required this.parentContext,
    required this.currentIndex,
    required this.scaffoldKey,
  });

  @override
  _CustomBottomNavBarState createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  bool isNavigating = false;

  void _onItemTapped(int index) {
    if (isNavigating) return;

    setState(() {
      isNavigating = true;
    });

    switch (index) {
      case 0:
        Navigator.push(widget.parentContext, MaterialPageRoute(builder: (context) => LevelsPage()))
            .then((_) {
          setState(() {
            isNavigating = false;
          });
        });
        break;
      case 1:
        Navigator.push(widget.parentContext, MaterialPageRoute(builder: (context) => ProfilePage()))
            .then((_) {
          setState(() {
            isNavigating = false;
          });
        });
        break;
      case 2:
        Navigator.push(widget.parentContext, MaterialPageRoute(builder: (context) => LessonsScreen()))
            .then((_) {
          setState(() {
            isNavigating = false;
          });
        });
        break;
      case 3:
        Navigator.push(widget.parentContext, MaterialPageRoute(builder: (context) => LeaderboardPage()))
            .then((_) {
          setState(() {
            isNavigating = false;
          });
        });
        break;
      case 4:
        Navigator.push(widget.parentContext, MaterialPageRoute(builder: (context) => SettingsScreen()))
            .then((_) {
          setState(() {
            isNavigating = false;
          });
        });
        break;
      default:
        setState(() {
          isNavigating = false;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      onTap: _onItemTapped,
      selectedItemColor: Colors.blue.shade800,
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: TextStyle(color: Colors.black87),
      unselectedLabelStyle: const TextStyle(color: Colors.grey),
      items: List.generate(5, (index) {
        return BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: _buildGradientIcon(
              _getIconData(index),
              index == widget.currentIndex ? Colors.blue.shade900: Colors.grey.shade400,
              index == widget.currentIndex ? Colors.blue.shade300 : Colors.grey.shade200,
              index == widget.currentIndex,
              _getIconColor(index),
            ),
          ),
          label: _getLabel(index),
        );
      }),
    );
  }

  IconData _getIconData(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.account_circle;
      case 2:
        return Icons.book;
      case 3:
        return Icons.leaderboard;
      case 4:
        return Icons.settings;
      default:
        return Icons.home;
    }
  }

  String _getLabel(int index) {
    switch (index) {
      case 0:
        return 'Accueil';
      case 1:
        return 'Profil';
      case 2:
        return 'Apprendre';
      case 3:
        return 'Top'; // Correction du label
      case 4:
        return 'Paramètres';
      default:
        return 'Accueil';
    }
  }

  Color _getIconColor(int index) {
    return Colors.white;
  }

  Widget _buildGradientIcon(IconData iconData, Color startColor, Color endColor, bool isSelected, Color iconColor) {
    return Container(
      width: isSelected ? 60 : 35,
      height: isSelected ? 60 : 35,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.yellow.shade700,
          width: isSelected ? 4.0 : 2.0,
        ),
      ),
      child: Center(
        child: Icon(iconData, color: iconColor, size: isSelected ? 30 : 20),
      ),
    );
  }
}
