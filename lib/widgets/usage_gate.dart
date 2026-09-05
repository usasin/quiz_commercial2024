import 'package:flutter/material.dart';

import '../services/usage_meter.dart';

class UsageGate extends StatelessWidget {
  final int requiresTextTokens;
  final int requiresAudioSeconds;

  final VoidCallback? onBlockedTap;
  final String blockedMessage;
  final Widget child;

  const UsageGate({
    super.key,
    this.requiresTextTokens = 0,
    this.requiresAudioSeconds = 0,
    required this.onBlockedTap,
    required this.blockedMessage,
    required this.child,
  });

  Future<bool> _isAllowed() async {
    final meter = UsageMeter();
    await meter.initIfNeeded();

    final premium = await meter.isPremium();
    if (premium) return true;

    if (requiresTextTokens > 0) {
      final ok = await meter.canUseText(requiresTextTokens);
      if (!ok) return false;
    }

    if (requiresAudioSeconds > 0) {
      final ok = await meter.canUseAudio(requiresAudioSeconds);
      if (!ok) return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAllowed(),
      builder: (context, snap) {
        final allowed = snap.data ?? true;

        if (allowed) return child;

        return InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(blockedMessage)),
            );
            onBlockedTap?.call();
          },
          borderRadius: BorderRadius.circular(14),
          child: Opacity(opacity: 0.55, child: child),
        );
      },
    );
  }
}
