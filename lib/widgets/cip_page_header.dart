import 'package:flutter/material.dart';

class CipPageHeader extends StatelessWidget {
  final String moduleTitle;
  final String pageTitle;
  final Color? moduleTitleColor;
  final Widget? subtitle;

  const CipPageHeader({
    super.key,
    required this.moduleTitle,
    required this.pageTitle,
    this.moduleTitleColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.10),
            cs.secondary.withOpacity(0.06),
            cs.tertiary.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: cs.outline.withOpacity(0.95))),
      ),
      child: Column(
        children: [
          Text(
            moduleTitle.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: moduleTitleColor ?? cs.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            pageTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
              height: 1.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            DefaultTextStyle(
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.72),
                fontWeight: FontWeight.w700,
              ),
              child: subtitle!,
            ),
          ],
        ],
      ),
    );
  }
}

class CipAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;

  const CipAppBar({super.key, this.onBackPressed, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        onPressed: onBackPressed ?? () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      actions: actions,
    );
  }
}
