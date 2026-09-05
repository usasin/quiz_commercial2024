import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_communication_service.dart';
import '../services/usage_meter.dart';

/// Affiche les communications créées depuis le Super Admin sur tous les écrans.
class AppCommunicationGate extends StatefulWidget {
  final Widget child;

  const AppCommunicationGate({super.key, required this.child});

  @override
  State<AppCommunicationGate> createState() => _AppCommunicationGateState();
}

class _AppCommunicationGateState extends State<AppCommunicationGate> {
  StreamSubscription<User?>? _authSubscription;
  int _currentBuild = 0;
  bool _premium = false;
  bool _ready = false;
  Set<String> _dismissed = const {};

  @override
  void initState() {
    super.initState();
    _loadState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      _loadAudience();
    });
  }

  Future<void> _loadState() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final prefs = await SharedPreferences.getInstance();
      final premium = await UsageMeter().isPremium();
      if (!mounted) return;
      setState(() {
        _currentBuild = int.tryParse(info.buildNumber) ?? 0;
        _premium = premium;
        _ready = true;
        _dismissed =
            (prefs.getStringList('dismissed_app_communications') ?? const [])
                .toSet();
      });
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _loadAudience() async {
    final premium = await UsageMeter().isPremium();
    if (mounted) setState(() => _premium = premium);
  }

  Future<void> _dismiss(String id) async {
    if (id.isEmpty) return;
    final updated = {..._dismissed, id};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'dismissed_app_communications',
      updated.take(100).toList(growable: false),
    );
    if (mounted) setState(() => _dismissed = updated);
  }

  bool _matchesAudience(AppCommunication item) {
    if (item.audience == 'premium') return _premium;
    if (item.audience == 'free') return !_premium;
    return true;
  }

  bool _matchesVersion(AppCommunication item) {
    if (item.kind != 'update') return true;
    if (item.forceUpdate) return _currentBuild < item.minimumBuild;
    if (item.latestBuild <= 0) return true;
    return _currentBuild < item.latestBuild;
  }

  Future<void> _openAction(AppCommunication item) async {
    final uri = Uri.tryParse(item.actionUrl.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppCommunication?>(
      stream: AppCommunicationService.watch(),
      builder: (context, snapshot) {
        if (!_ready) return widget.child;
        final item = snapshot.data;
        final now = DateTime.now();
        final mandatory = item != null &&
            item.kind == 'update' &&
            item.forceUpdate &&
            _currentBuild < item.minimumBuild;
        final hidden = item == null ||
            !item.isActiveAt(now) ||
            !_matchesAudience(item) ||
            !_matchesVersion(item) ||
            (!mandatory && _dismissed.contains(item.id));

        if (hidden) return widget.child;

        if (item.displayMode == 'banner' && !mandatory) {
          return Stack(
            children: [
              widget.child,
              Positioned(
                left: 10,
                right: 10,
                top: MediaQuery.paddingOf(context).top + 8,
                child: _Banner(
                  item: item,
                  onAction: item.actionUrl.isEmpty ? null : () => _openAction(item),
                  onDismiss: item.dismissible ? () => _dismiss(item.id) : null,
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: _FullMessage(
                item: item,
                mandatory: mandatory,
                onAction: item.actionUrl.isEmpty ? null : () => _openAction(item),
                onDismiss: (!mandatory && item.dismissible)
                    ? () => _dismiss(item.id)
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  final AppCommunication item;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const _Banner({required this.item, this.onAction, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      color: const Color(0xFF10243A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: Color(0xFF5AACDB)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900)),
                  Text(item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            if (onAction != null)
              TextButton(onPressed: onAction, child: Text(item.actionLabel)),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullMessage extends StatelessWidget {
  final AppCommunication item;
  final bool mandatory;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const _FullMessage({
    required this.item,
    required this.mandatory,
    this.onAction,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final fullScreen = item.displayMode == 'fullscreen' || mandatory;
    return Material(
      color: fullScreen ? const Color(0xFF0D1B2A) : Colors.black54,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: fullScreen ? 0 : 18,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.imageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            item.imageUrl,
                            height: 190,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ] else ...[
                        Icon(
                          item.kind == 'update'
                              ? Icons.system_update_rounded
                              : Icons.campaign_rounded,
                          size: 54,
                          color: const Color(0xFF5AACDB),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D1B2A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      if (onAction != null)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onAction,
                            icon: Icon(item.kind == 'update'
                                ? Icons.download_rounded
                                : Icons.open_in_new_rounded),
                            label: Text(item.actionLabel.isEmpty
                                ? 'En savoir plus'
                                : item.actionLabel),
                          ),
                        ),
                      if (onDismiss != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onDismiss,
                          child: const Text('Plus tard'),
                        ),
                      ],
                      if (mandatory)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Cette mise à jour est nécessaire pour continuer.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
