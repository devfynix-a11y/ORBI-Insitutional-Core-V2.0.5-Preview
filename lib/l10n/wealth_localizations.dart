import 'app_localizations.dart';

extension WealthLocalizations on AppLocalizations {
  bool get isSw => localeName.toLowerCase() == 'sw';

  String pick({required String en, required String swText}) => isSw ? swText : en;
}
