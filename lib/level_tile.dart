import 'package:flutter/material.dart';


class LevelTile extends StatelessWidget {
  final int level;
  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  LevelTile({
    required this.level,
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.shade50.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Image.network(imageUrl, height: 60, width: 60),
            SizedBox(height: 10),
            Text(title),
          ],
        ),
      ),
    );
  }
}
