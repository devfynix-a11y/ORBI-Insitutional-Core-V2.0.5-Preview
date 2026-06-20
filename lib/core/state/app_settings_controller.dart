import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsController extends ChangeNotifier {
  static const String _prefLanguageCode = 'settings_app_language_code';
  static const String _prefApplyToApp = 'settings_app_language_apply';
  static const String _prefWelcomeFlowCompleted = 'settings_welcome_flow_done';
  static const String _prefHideBalances = 'settings_hide_balances';
  static const String _prefBudgetLockEnabled = 'settings_budget_lock_enabled';
  static const String _prefInsightViewEnabled = 'settings_insight_view_enabled';
  static const String _prefUnlockedWalletIds = 'settings_unlocked_wallet_ids';
  static const String hiddenBalanceText = '••••••';

  Locale? _appLocale;
  bool _isLoaded = false;
  bool _welcomeFlowCompleted = false;
  bool _hideBalances = true;
  bool _budgetLockEnabled = false;
  bool _insightViewEnabled = false;
  Set<String> _unlockedWalletIds = <String>{};

  bool get isLoaded => _isLoaded;
  Locale? get appLocale => _appLocale;
  bool get welcomeFlowCompleted => _welcomeFlowCompleted;
  bool get hideBalances => _hideBalances;
  bool get budgetLockEnabled => _budgetLockEnabled;
  bool get insightViewEnabled => _insightViewEnabled;
  List<String> get unlockedWalletIds => List.unmodifiable(_unlockedWalletIds);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefLanguageCode);
    final apply = prefs.getBool(_prefApplyToApp) ?? false;
    _welcomeFlowCompleted = prefs.getBool(_prefWelcomeFlowCompleted) ?? false;
    _hideBalances = true;
    await prefs.setBool(_prefHideBalances, true);
    _budgetLockEnabled = prefs.getBool(_prefBudgetLockEnabled) ?? false;
    _insightViewEnabled = prefs.getBool(_prefInsightViewEnabled) ?? false;
    _unlockedWalletIds =
        (prefs.getStringList(_prefUnlockedWalletIds) ?? const <String>[])
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet();
    if (apply && code != null && code.isNotEmpty) {
      _appLocale = Locale(code);
    } else {
      _appLocale = null;
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setAppLanguage({
    required String languageCode,
    required bool applyToApp,
  }) async {
    await persistAppLanguage(
      languageCode: languageCode,
      applyToApp: applyToApp,
    );
    _appLocale = applyToApp ? Locale(languageCode) : null;
    notifyListeners();
  }

  static Future<void> persistAppLanguage({
    required String languageCode,
    required bool applyToApp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLanguageCode, languageCode);
    await prefs.setBool(_prefApplyToApp, applyToApp);
  }

  Future<void> completeWelcomeFlow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefWelcomeFlowCompleted, true);
    _welcomeFlowCompleted = true;
    notifyListeners();
  }

  Future<void> setHideBalances(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefHideBalances, value);
    _hideBalances = value;
    notifyListeners();
  }

  Future<void> toggleHideBalances() async {
    await setHideBalances(!_hideBalances);
  }

  Future<void> setBudgetLockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefBudgetLockEnabled, value);
    _budgetLockEnabled = value;
    notifyListeners();
  }

  Future<void> toggleBudgetLockEnabled() async {
    await setBudgetLockEnabled(!_budgetLockEnabled);
  }

  Future<void> setInsightViewEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefInsightViewEnabled, value);
    _insightViewEnabled = value;
    notifyListeners();
  }

  Future<void> toggleInsightViewEnabled() async {
    await setInsightViewEnabled(!_insightViewEnabled);
  }

  bool isWalletUnlocked(String walletId) {
    if (walletId.trim().isEmpty) return false;
    return _unlockedWalletIds.contains(walletId);
  }

  Future<void> unlockWallet(String walletId) async {
    final trimmed = walletId.trim();
    if (trimmed.isEmpty) return;
    if (_unlockedWalletIds.contains(trimmed)) return;
    _unlockedWalletIds = {..._unlockedWalletIds, trimmed};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefUnlockedWalletIds,
      _unlockedWalletIds.toList(),
    );
    notifyListeners();
  }

  Future<void> lockWallet(String walletId) async {
    final trimmed = walletId.trim();
    if (trimmed.isEmpty) return;
    if (!_unlockedWalletIds.contains(trimmed)) return;
    _unlockedWalletIds = {..._unlockedWalletIds}..remove(trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefUnlockedWalletIds,
      _unlockedWalletIds.toList(),
    );
    notifyListeners();
  }

  Future<void> clearUnlockedWallets() async {
    if (_unlockedWalletIds.isEmpty) return;
    _unlockedWalletIds = <String>{};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefUnlockedWalletIds, const <String>[]);
    notifyListeners();
  }
}
