import 'dart:math';
import 'package:flutter/material.dart';

/// Un halo dégradé qui tourne uniquement sur le TRAIT du conteneur.
/// ---------------------------------------------------------------
/// - [borderWidth]  épaisseur du trait animé
/// - [borderRadius] rayon des coins (mets 9999 pour un cercle)
/// - [colors]       les couleurs du dégradé
/// - [duration]     temps pour faire un tour complet
class RotatingGlowBorder extends StatefulWidget {
  const RotatingGlowBorder({
    Key?     key,
    required this.child,
    this.borderWidth  = 4.0,
    this.borderRadius = 16.0,
    this.colors  = const [Colors.cyanAccent, Colors.blueAccent, Colors.cyanAccent],
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);

  final Widget        child;
  final double        borderWidth;
  final double        borderRadius;
  final List<Color>   colors;
  final Duration      duration;

  @override
  State<RotatingGlowBorder> createState() => _RotatingGlowBorderState();
}

class _RotatingGlowBorderState extends State<RotatingGlowBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        //  Le painter ne redessine que lorsque l’animation change
        foregroundPainter: _GlowPainter(
          animation: _ctrl,
          colors:   widget.colors,
          stroke:   widget.borderWidth,
          radius:   widget.borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}

/// ----------------------------------------------------------------
/// Painter privé : dégradé circulaire qui tourne, en **stroke only**
class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.animation,
    required this.colors,
    required this.stroke,
    required this.radius,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Color>       colors;
  final double            stroke;
  final double            radius;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dégradé sweep qui tourne avec l’animation
    final shader = SweepGradient(
      colors: colors,
      startAngle: 0,
      endAngle: pi * 2,
      transform: GradientRotation(animation.value * 2 * pi),
    ).createShader(Offset.zero & size);

    // 2. Pinceau : trait uniquement
    final paint = Paint()
      ..shader = shader
      ..style  = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;

    // 3. Dessin du rectangle arrondi (ou cercle) décalé pour ne
    //    pas rogner le trait
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(stroke / 2),
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.colors  != colors  ||
          old.stroke  != stroke  ||
          old.radius  != radius  ||
          old.animation != animation;
}
