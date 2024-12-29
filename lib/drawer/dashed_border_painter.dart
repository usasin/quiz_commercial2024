import 'package:flutter/material.dart';

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    this.color = Colors.white, // Ici, changez la couleur par défaut en blanc
    this.dashWidth = 8.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    double currentX = 0;
    double currentY = 0;

    while (currentX < size.width) {
      canvas.drawLine(Offset(currentX, 0), Offset(currentX + dashWidth, 0), paint);
      currentX += dashWidth + dashSpace;
    }

    while (currentY < size.height) {
      canvas.drawLine(Offset(size.width, currentY), Offset(size.width, currentY + dashWidth), paint);
      currentY += dashWidth + dashSpace;
    }

    currentX = size.width;
    while (currentX > 0) {
      canvas.drawLine(Offset(currentX, size.height), Offset(currentX - dashWidth, size.height), paint);
      currentX -= dashWidth + dashSpace;
    }

    currentY = size.height;
    while (currentY > 0) {
      canvas.drawLine(Offset(0, currentY), Offset(0, currentY - dashWidth), paint);
      currentY -= dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
