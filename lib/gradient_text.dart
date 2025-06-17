import 'dart:math';
import 'package:flutter/material.dart';

class GradientText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const GradientText(this.text, {Key? key, required this.style, required LinearGradient gradient}) : super(key: key);
  @override
  _GradientTextState createState() => _GradientTextState();
}

class _GradientTextState extends State<GradientText> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds:3))
      ..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors:  [Colors.blue.shade800,Colors.blue.shade300, Colors.blue.shade800],
              stops: [
                (_ctrl.value - 0.3).clamp(0.0,1.0),
                _ctrl.value,
                (_ctrl.value + 0.3).clamp(0.0,1.0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(Rect.fromLTWH(0,0,bounds.width,bounds.height));
          },
          child: Text(widget.text, style: widget.style.copyWith(color: Colors.white)),
        );
      },
    );
  }
}
