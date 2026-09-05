/// ✅ Centralise tous les liens Play Store ici
/// IMPORTANT: remplace par le vrai packageName de EmploiBoost
class AppStoreLinks {
  static const String packageName = 'com.emploiboost.emploiboost';

  static const String webShareUrl =
      'https://play.google.com/store/apps/details?id=$packageName&pcampaignid=web_share';

  static Uri marketUri() => Uri.parse('market://details?id=$packageName');
  static Uri webUri() => Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
}
