import 'package:flutter_test/flutter_test.dart';
import 'package:emploiboost/services/localized_firestore.dart';

void main() {
  group('LocalizedFirestore', () {
    const raw = <String, dynamic>{
      'title': 'Titre français',
      'briefing': <String, dynamic>{
        'intro': 'Introduction française',
        'duration': 6,
      },
      'options': <String>['Oui', 'Non'],
      'i18n': <String, dynamic>{
        'en': <String, dynamic>{
          'title': 'English title',
          'briefing': <String, dynamic>{'intro': 'English introduction'},
          'options': <String>['Yes', 'No'],
        },
      },
    };

    test('uses the French base and removes localization metadata', () {
      final result = LocalizedFirestore.forLanguage(raw, 'fr');

      expect(result['title'], 'Titre français');
      expect(result.containsKey('i18n'), isFalse);
    });

    test('deep-merges the requested language and replaces arrays', () {
      final result = LocalizedFirestore.forLanguage(raw, 'en');

      expect(result['title'], 'English title');
      expect(result['briefing'], <String, dynamic>{
        'intro': 'English introduction',
        'duration': 6,
      });
      expect(result['options'], <String>['Yes', 'No']);
    });

    test('falls back to French when the locale has no overlay', () {
      final result = LocalizedFirestore.forLanguage(raw, 'de');

      expect(result['title'], 'Titre français');
      expect(result.containsKey('i18n'), isFalse);
    });
  });
}
