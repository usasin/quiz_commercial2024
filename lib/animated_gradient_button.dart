import 'package:flutter/material.dart';

class AnimatedGradientButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const AnimatedGradientButton({
    Key? key,
    required this.child,
    this.onTap,
  }) : super(key: key);
  @override
  _AnimatedGradientButtonState createState() => _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<AnimatedGradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical:12, horizontal:24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [Colors.blueAccent, Colors.cyan, Colors.blue],
                stops: [
                  (_anim.value - 0.3).clamp(0.0,1.0),
                  _anim.value,
                  (_anim.value + 0.3).clamp(0.0,1.0),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius:4, offset: Offset(0,2))
              ],
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}
