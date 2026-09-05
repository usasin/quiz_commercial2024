import 'dart:math';
import 'package:flutter/material.dart';

/// RotatingGlowBorder
/// - Dessine un trait (stroke) animé en dégradé qui tourne autour du child.
/// - Ajoute un padding interne pour éviter que le trait recouvre le contenu.
class RotatingGlowBorder extends StatefulWidget {
  const RotatingGlowBorder({
    super.key,
    required this.child,
    this.borderWidth = 3.0,
    this.borderRadius = 16.0,
    this.colors = const [
      Colors.cyanAccent,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.cyanAccent,
    ],
    this.duration = const Duration(seconds: 2),
    this.padding,
  }) : assert(colors.length >= 2, 'colors must have at least 2 colors');

  final Widget child;
  final double borderWidth;
  final double borderRadius;
  final List<Color> colors;
  final Duration duration;

  /// Si null -> padding auto = borderWidth + 2
  final EdgeInsets? padding;

  @override
  State<RotatingGlowBorder> createState() => _RotatingGlowBorderState();
}

class _RotatingGlowBorderState extends State<RotatingGlowBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void didUpdateWidget(covariant RotatingGlowBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _ctrl
        ..duration = widget.duration
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.padding ?? EdgeInsets.all(widget.borderWidth + 2);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: CustomPaint(
        foregroundPainter: _GlowPainter(
          animation: _ctrl,
          colors: widget.colors,
          stroke: widget.borderWidth,
          radius: widget.borderRadius,
        ),
        child: Padding(
          padding: pad,
          child: widget.child,
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.animation,
    required this.colors,
    required this.stroke,
    required this.radius,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Color> colors;
  final double stroke;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Sweep gradient qui tourne
    final shader = SweepGradient(
      colors: colors,
      startAngle: 0,
      endAngle: pi * 2,
      transform: GradientRotation(animation.value * 2 * pi),
    ).createShader(rect);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(stroke / 2),
      Radius.circular(radius),
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return oldDelegate.stroke != stroke ||
        oldDelegate.radius != radius ||
        oldDelegate.colors != colors ||
        oldDelegate.animation != animation;
  }
}
