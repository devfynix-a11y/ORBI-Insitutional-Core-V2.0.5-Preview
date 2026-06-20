import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import 'notification_preferences_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const String _androidNotificationIcon = 'ic_stat_orbi_notification';
  static const String _androidAlertChannelId = 'orbi_alert_notifications_v2';
  String? _fcmToken;
  StreamSubscription<String>? _tokenRefreshSub;
  Future<void>? _initializeFuture;
  bool _localNotificationsReady = false;
  bool _isSyncingToken = false;
  String? _lastSyncedToken;

  static const AndroidNotificationChannel _foregroundChannel =
      AndroidNotificationChannel(
        _androidAlertChannelId,
        'ORBI Alerts',
        description: 'High priority ORBI account and money alerts.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    // Make initialization idempotent so call sites can safely invoke it.
    _initializeFuture ??= _initializeInternal();
    return _initializeFuture!;
  }

  Future<void> _initializeInternal() async {
    try {
      // Initialize Firebase (loads iOS config from ios/Runner/GoogleService-Info.plist).
      await Firebase.initializeApp();

      // Important: only access FirebaseMessaging after Firebase.initializeApp().
      _firebaseMessaging ??= FirebaseMessaging.instance;
      final messaging = _firebaseMessaging!;
      final prefs = await NotificationPreferencesService.instance.load();

      await _initializeLocalNotifications();

      NotificationSettings settings;
      if (prefs.pushNotificationsEnabled) {
        settings = await _requestNotificationPermission(messaging);
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else {
        settings = await messaging.getNotificationSettings();
        await messaging.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
        await _clearToken(messaging);
      }

      debugPrint('🔥 [FCM] Permission status: ${settings.authorizationStatus}');

      // Get FCM token
      await _getFCMToken();

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      debugPrint('🔥 [FCM] Firebase initialized successfully');
    } catch (e) {
      debugPrint('❌ [FCM] Failed to initialize Firebase: $e');
      // Allow retry if initialization failed (common when config files are missing).
      _initializeFuture = null;
    }
  }

  Future<void> _getFCMToken() async {
    try {
      // Ensure messaging is initialized.
      _firebaseMessaging ??= FirebaseMessaging.instance;
      final messaging = _firebaseMessaging!;
      final prefs = await NotificationPreferencesService.instance.load();
      if (!prefs.pushNotificationsEnabled) {
        await _clearToken(messaging);
        return;
      }

      _fcmToken = await messaging.getToken();
      debugPrint('🔥 [FCM] Token: $_fcmToken');
      await _syncTokenToBackend(_fcmToken);

      if (_fcmToken == null && defaultTargetPlatform == TargetPlatform.iOS) {
        // On iOS, an APNs token is required for FCM token generation.
        final apnsToken = await messaging.getAPNSToken();
        debugPrint('[FCM] APNs token (iOS): $apnsToken');
      }

      // Listen for token refresh
      _tokenRefreshSub ??= messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔥 [FCM] Token refreshed: $newToken');
        _fcmToken = newToken;
        await _syncTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint('❌ [FCM] Failed to get token: $e');
    }
  }

  Future<String?> getToken() async {
    // Ensure Firebase is initialized before attempting token retrieval.
    await initialize();
    final prefs = await NotificationPreferencesService.instance.load();
    if (!prefs.pushNotificationsEnabled) {
      return null;
    }
    if (_fcmToken == null) {
      await _getFCMToken();
    }
    return _fcmToken;
  }

  Future<String?> syncTokenAfterAuthentication() async {
    await initialize();
    final prefs = await NotificationPreferencesService.instance.load();
    if (!prefs.pushNotificationsEnabled) return null;

    if (_fcmToken == null) {
      await _getFCMToken();
    } else {
      await _syncTokenToBackend(_fcmToken, force: true);
    }
    return _fcmToken;
  }

  Future<String?> setPushEnabled(bool enabled) async {
    await initialize();
    final prefs = await NotificationPreferencesService.instance.load();
    await NotificationPreferencesService.instance.saveDevicePreferences(
      pushEnabled: enabled,
      emailAlertsEnabled: prefs.emailAlertsEnabled,
      marketingEnabled: prefs.marketingEnabled,
    );
    await NotificationPreferencesService.instance.saveServicePreferences(
      notifPush: enabled,
      notifEmail: prefs.emailChannelEnabled,
      notifSecurity: prefs.notifSecurity,
      notifFinancial: prefs.notifFinancial,
      notifBudget: prefs.notifBudget,
      notifMarketing: prefs.notifMarketing,
    );

    _firebaseMessaging ??= FirebaseMessaging.instance;
    final messaging = _firebaseMessaging!;
    if (!enabled) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      await _clearToken(messaging);
      return null;
    }

    await _requestNotificationPermission(messaging);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _getFCMToken();
    return _fcmToken;
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady) return;

    const androidSettings = AndroidInitializationSettings(
      _androidNotificationIcon,
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_foregroundChannel);
    await androidPlugin?.requestNotificationsPermission();

    _localNotificationsReady = true;
  }

  Future<void> showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsReady) {
      await _initializeLocalNotifications();
    }
    final prefs = await NotificationPreferencesService.instance.load();
    final category =
        message.data['category'] ??
        message.data['type'] ??
        message.data['event'] ??
        message.data['event_code'] ??
        message.data['eventCode'] ??
        message.data['template_name'] ??
        message.data['templateName'];
    if (!prefs.pushNotificationsEnabled ||
        !prefs.allowsCategory(category?.toString())) {
      debugPrint(
        '🔕 [FCM] Suppressed foreground notification due to preferences: '
        '$category',
      );
      return;
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    try {
      await _localNotifications.show(
        message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title ?? 'ORBI',
        body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _foregroundChannel.id,
            _foregroundChannel.name,
            channelDescription: _foregroundChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            ticker: 'ORBI alert',
            visibility: NotificationVisibility.public,
            icon: _androidNotificationIcon,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: message.data.isEmpty ? null : message.data.toString(),
      );
    } catch (e) {
      debugPrint('❌ [FCM] Failed to show foreground notification: $e');
    }
  }

  Future<NotificationSettings> _requestNotificationPermission(
    FirebaseMessaging messaging,
  ) {
    return messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _clearToken(FirebaseMessaging messaging) async {
    try {
      await messaging.deleteToken();
    } catch (e) {
      debugPrint('⚠️ [FCM] Failed to delete token: $e');
    }
    _fcmToken = null;
    await _syncTokenToBackend(null);
  }

  Future<void> _syncTokenToBackend(String? token, {bool force = false}) async {
    if (_isSyncingToken) return;
    if (!force && _lastSyncedToken == token) return;

    _isSyncingToken = true;
    try {
      await ApiClient().client.patch(
        AppConfig.endpoints['profile']!,
        data: {'fcm_token': token},
      );
      _lastSyncedToken = token;
      debugPrint('🔥 [FCM] Synced token to backend');
    } catch (e) {
      debugPrint('⚠️ [FCM] Failed to sync token to backend: $e');
    } finally {
      _isSyncingToken = false;
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔥 [FCM] Background message: ${message.messageId}');
  await _showBackgroundLocalNotification(message);
}

// Foreground message handler
void _handleForegroundMessage(RemoteMessage message) {
  debugPrint('🔥 [FCM] Foreground message: ${message.notification?.title}');
  FirebaseService().showForegroundNotification(message);
}

// Handle when app is opened from notification
void _handleMessageOpenedApp(RemoteMessage message) {
  debugPrint('🔥 [FCM] Message opened app: ${message.messageId}');
  // Navigate to specific screen based on message data
}

Future<void> _showBackgroundLocalNotification(RemoteMessage message) async {
  // Android/iOS will display notification payloads automatically in the
  // background. This path handles backend data-only pushes.
  if (message.notification != null) return;

  final title = message.data['title']?.toString();
  final body = message.data['body']?.toString();
  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return;
  }

  final prefs = await NotificationPreferencesService.instance.load();
  final category =
      message.data['category'] ??
      message.data['type'] ??
      message.data['event'] ??
      message.data['event_code'] ??
      message.data['eventCode'] ??
      message.data['template_name'] ??
      message.data['templateName'];
  if (!prefs.pushNotificationsEnabled ||
      !prefs.allowsCategory(category?.toString())) {
    return;
  }

  const channel = AndroidNotificationChannel(
    FirebaseService._androidAlertChannelId,
    'ORBI Alerts',
    description: 'High priority ORBI account and money alerts.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );
  final localNotifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings(
    FirebaseService._androidNotificationIcon,
  );
  const settings = InitializationSettings(android: androidSettings);
  await localNotifications.initialize(settings);
  final androidPlugin = localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(channel);
  await localNotifications.show(
    message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title ?? 'ORBI',
    body ?? '',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        FirebaseService._androidAlertChannelId,
        'ORBI Alerts',
        channelDescription: 'High priority ORBI account and money alerts.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ticker: 'ORBI alert',
        visibility: NotificationVisibility.public,
        icon: FirebaseService._androidNotificationIcon,
      ),
    ),
    payload: message.data.isEmpty ? null : message.data.toString(),
  );
}
