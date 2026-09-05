import 'package:emploiboost/services/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget testApp(Locale locale) {
    return Localizations(
      locale: locale,
      delegates: const <LocalizationsDelegate<dynamic>>[
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) =>
              Text(context.bilingual(fr: 'Leçons', en: 'Lessons')),
        ),
      ),
    );
  }

  testWidgets('renders the French interface label', (tester) async {
    await tester.pumpWidget(testApp(const Locale('fr')));
    expect(find.text('Leçons'), findsOneWidget);
    expect(find.text('Lessons'), findsNothing);
  });

  testWidgets('renders the English interface label', (tester) async {
    await tester.pumpWidget(testApp(const Locale('en')));
    expect(find.text('Lessons'), findsOneWidget);
    expect(find.text('Leçons'), findsNothing);
  });
}
