import 'package:flutter/widgets.dart';

/// Resolves Firestore content stored as a French base document with optional
/// locale overlays under `i18n.<languageCode>`.
class LocalizedFirestore {
  const LocalizedFirestore._();

  static Map<String, dynamic> data(
    BuildContext context,
    Map<String, dynamic> raw,
  ) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return forLanguage(raw, languageCode);
  }

  static Map<String, dynamic> forLanguage(
    Map<String, dynamic> raw,
    String languageCode,
  ) {
    final base = Map<String, dynamic>.from(raw)..remove('i18n');
    if (languageCode == 'fr') return base;

    final i18n = raw['i18n'];
    if (i18n is! Map) return base;
    final localized = i18n[languageCode];
    if (localized is! Map) return base;
    return _merge(base, Map<String, dynamic>.from(localized));
  }

  static Map<String, dynamic> _merge(
    Map<String, dynamic> base,
    Map<String, dynamic> overlay,
  ) {
    final result = Map<String, dynamic>.from(base);
    for (final entry in overlay.entries) {
      final current = result[entry.key];
      final replacement = entry.value;
      if (current is Map && replacement is Map) {
        result[entry.key] = _merge(
          Map<String, dynamic>.from(current),
          Map<String, dynamic>.from(replacement),
        );
      } else {
        result[entry.key] = replacement;
      }
    }
    return result;
  }
}
