import 'package:flutter/widgets.dart';

extension AppLanguage on BuildContext {
  bool get isEnglish => Localizations.localeOf(this).languageCode == 'en';

  String bilingual({required String fr, required String en}) {
    return isEnglish ? en : fr;
  }
}
