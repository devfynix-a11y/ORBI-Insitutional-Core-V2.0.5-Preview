import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferenceSnapshot {
  const NotificationPreferenceSnapshot({
    required this.pushEnabled,
    required this.emailAlertsEnabled,
    required this.marketingEnabled,
    required this.pushChannelEnabled,
    required this.emailChannelEnabled,
    required this.notifSecurity,
    required this.notifFinancial,
    required this.notifBudget,
    required this.notifMarketing,
  });

  final bool pushEnabled;
  final bool emailAlertsEnabled;
  final bool marketingEnabled;
  final bool pushChannelEnabled;
  final bool emailChannelEnabled;
  final bool notifSecurity;
  final bool notifFinancial;
  final bool notifBudget;
  final bool notifMarketing;

  bool get pushNotificationsEnabled => pushEnabled && pushChannelEnabled;

  bool allowsCategory(String? rawCategory) {
    final category = rawCategory?.trim().toLowerCase();
    if (category == null || category.isEmpty) return true;

    if (category.contains('security') ||
        category.contains('login') ||
        category.contains('fraud')) {
      return notifSecurity;
    }
    if (category.contains('budget') || category.contains('goal')) {
      return notifBudget;
    }
    if (category.contains('marketing') ||
        category.contains('promo') ||
        category.contains('promotion') ||
        category.contains('offer')) {
      return notifMarketing && marketingEnabled;
    }
    if (category == 'info') {
      return notifFinancial || notifBudget;
    }
    if (category.contains('financial') ||
        category.contains('payment') ||
        category.contains('transaction') ||
        category.contains('transfer') ||
        category.contains('wallet') ||
        category == 'update') {
      return notifFinancial;
    }
    return true;
  }
}

class NotificationPreferencesService {
  NotificationPreferencesService._();

  static final NotificationPreferencesService instance =
      NotificationPreferencesService._();

  static const String prefPush = 'settings_push_enabled';
  static const String prefEmailAlerts = 'settings_email_alerts_enabled';
  static const String prefMarketing = 'settings_marketing_enabled';
  static const String prefNotifPush = 'settings_notif_push';
  static const String prefNotifEmail = 'settings_notif_email';
  static const String prefNotifSecurity = 'settings_notif_security';
  static const String prefNotifFinancial = 'settings_notif_financial';
  static const String prefNotifBudget = 'settings_notif_budget';
  static const String prefNotifMarketing = 'settings_notif_marketing';

  Future<NotificationPreferenceSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferenceSnapshot(
      pushEnabled: prefs.getBool(prefPush) ?? true,
      emailAlertsEnabled: prefs.getBool(prefEmailAlerts) ?? true,
      marketingEnabled: prefs.getBool(prefMarketing) ?? false,
      pushChannelEnabled: prefs.getBool(prefNotifPush) ?? true,
      emailChannelEnabled: prefs.getBool(prefNotifEmail) ?? true,
      notifSecurity: prefs.getBool(prefNotifSecurity) ?? true,
      notifFinancial: prefs.getBool(prefNotifFinancial) ?? true,
      notifBudget: prefs.getBool(prefNotifBudget) ?? true,
      notifMarketing: prefs.getBool(prefNotifMarketing) ?? false,
    );
  }

  Future<void> saveDevicePreferences({
    required bool pushEnabled,
    required bool emailAlertsEnabled,
    required bool marketingEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefPush, pushEnabled);
    await prefs.setBool(prefEmailAlerts, emailAlertsEnabled);
    await prefs.setBool(prefMarketing, marketingEnabled);
  }

  Future<void> saveServicePreferences({
    required bool notifPush,
    required bool notifEmail,
    required bool notifSecurity,
    required bool notifFinancial,
    required bool notifBudget,
    required bool notifMarketing,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefNotifPush, notifPush);
    await prefs.setBool(prefNotifEmail, notifEmail);
    await prefs.setBool(prefNotifSecurity, notifSecurity);
    await prefs.setBool(prefNotifFinancial, notifFinancial);
    await prefs.setBool(prefNotifBudget, notifBudget);
    await prefs.setBool(prefNotifMarketing, notifMarketing);
  }
}
