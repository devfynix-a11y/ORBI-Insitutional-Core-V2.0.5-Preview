import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/orbi_request_headers.dart';
import '../../../core/network/websocket/websocket_service.dart';
import '../../../core/security/device_fingerprint.dart';
import '../../../core/utils/user_facing_error.dart';

enum NotificationKind { security, payment, system, marketing, kyc, goal, other }

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? category;
  final NotificationKind kind;
  final Color color;
  final IconData icon;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    required this.kind,
    required this.color,
    required this.icon,
    this.category,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      category: category,
      kind: kind,
      color: color,
      icon: icon,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final category = json['category']?.toString();
    final kind = _kindFromCategoryOrType(category ?? json['type']?.toString());
    final tsRaw = json['timestamp'] ?? json['created_at'] ?? json['createdAt'];
    DateTime parsedTs = DateTime.now();
    if (tsRaw is String) {
      parsedTs = DateTime.tryParse(tsRaw)?.toLocal() ?? DateTime.now();
    } else if (tsRaw is int) {
      parsedTs = DateTime.fromMillisecondsSinceEpoch(
        tsRaw,
        isUtc: true,
      ).toLocal();
    }

    final isReadRaw = json['is_read'] ?? json['read'] ?? json['seen'] ?? false;
    final isRead = isReadRaw is bool
        ? isReadRaw
        : (isReadRaw is num ? isReadRaw == 1 : false);

    return NotificationItem(
      id:
          (json['id'] ??
                  json['notification_id'] ??
                  json['uuid'] ??
                  const Uuid().v4())
              .toString(),
      title: (json['title'] ?? json['subject'] ?? 'Notification')
          .toString()
          .trim(),
      message: (json['message'] ?? json['body'] ?? '').toString().trim(),
      timestamp: parsedTs,
      isRead: isRead,
      category: category,
      kind: kind,
      color: _colorForKind(kind),
      icon: _iconForKind(kind),
    );
  }

  factory NotificationItem.fromRealtime(Map<String, dynamic> payload) {
    final token = _notificationTokenFromPayload(payload);
    final category =
        payload['category']?.toString() ??
        payload['template_name']?.toString() ??
        payload['event_code']?.toString() ??
        payload['type']?.toString();
    final kind = _kindFromCategoryOrType(token);
    return NotificationItem.fromJson({
      'id': payload['id'] ?? payload['notification_id'],
      'title':
          payload['subject'] ??
          payload['title'] ??
          _defaultTitleForNotificationToken(token),
      'message':
          payload['body'] ??
          payload['message'] ??
          _defaultMessageForNotificationToken(token),
      'timestamp': payload['timestamp'] ?? payload['created_at'],
      'is_read': payload['is_read'],
      'category': category,
      'kind': kind,
    });
  }
}

String _notificationTokenFromPayload(Map<String, dynamic> payload) {
  return (payload['template_name'] ??
          payload['event_code'] ??
          payload['category'] ??
          payload['type'])
      .toString();
}

String _defaultTitleForNotificationToken(String? raw) {
  final value = raw?.toLowerCase().trim() ?? '';
  if (value.contains('merchant_service_update') ||
      value.contains('merchant_payment')) {
    return 'Merchant activity';
  }
  if (value.contains('merchant_customer_payment_update')) {
    return 'Merchant payment update';
  }
  if (value.contains('agent_cash_update') || value.contains('agent_cash')) {
    return 'Agent cash activity';
  }
  if (value.contains('agent_customer_cash_update')) {
    return 'Cash service update';
  }
  if (value.contains('agent_commission_paid')) {
    return 'Agent commission';
  }
  if (value.contains('service_customer_registered') ||
      value.contains('service_customer_onboarded')) {
    return 'Customer registration';
  }
  if (value.contains('service_access_approved')) {
    return 'Service access approved';
  }
  return 'Notification';
}

String _defaultMessageForNotificationToken(String? raw) {
  final value = raw?.toLowerCase().trim() ?? '';
  if (value.contains('merchant_service_update')) {
    return 'Your merchant activity has a new update.';
  }
  if (value.contains('merchant_customer_payment_update')) {
    return 'Your merchant-serviced payment has a new update.';
  }
  if (value.contains('agent_cash_update')) {
    return 'Your agent cash activity has a new update.';
  }
  if (value.contains('agent_customer_cash_update')) {
    return 'Your cash service request has a new update.';
  }
  if (value.contains('agent_commission_paid')) {
    return 'A new agent commission was paid to your account.';
  }
  if (value.contains('service_customer_registered') ||
      value.contains('service_customer_onboarded')) {
    return 'A service customer registration update is available.';
  }
  if (value.contains('service_access_approved')) {
    return 'Your ORBI service access has been approved.';
  }
  return '';
}

NotificationKind _kindFromCategoryOrType(String? raw) {
  final value = raw?.toLowerCase().trim() ?? '';
  if (value.isEmpty) return NotificationKind.other;
  if (value.contains('security') ||
      value.contains('login') ||
      value.contains('fraud')) {
    return NotificationKind.security;
  }
  if (value.contains('payment') ||
      value.contains('transaction') ||
      value.contains('transfer') ||
      value.contains('merchant') ||
      value.contains('agent_cash') ||
      value.contains('merchant_service_update') ||
      value.contains('merchant_customer_payment_update') ||
      value.contains('agent_customer_cash_update') ||
      value.contains('agent_commission_paid') ||
      value.contains('cash_deposit') ||
      value.contains('cash_withdraw')) {
    return NotificationKind.payment;
  }
  if (value.contains('system') ||
      value.contains('system_alert') ||
      value.contains('update') ||
      value.contains('service_access_approved') ||
      value.contains('service_customer_registered') ||
      value.contains('service_customer_onboarded')) {
    return NotificationKind.system;
  }
  if (value.contains('marketing') ||
      value.contains('promo') ||
      value.contains('promotion')) {
    return NotificationKind.marketing;
  }
  if (value.contains('kyc') ||
      value.contains('compliance') ||
      value.contains('verification')) {
    return NotificationKind.kyc;
  }
  if (value.contains('goal')) {
    return NotificationKind.goal;
  }
  return NotificationKind.other;
}

Color _colorForKind(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.security:
      return const Color(0xFFFFB020); // amber
    case NotificationKind.payment:
      return const Color(0xFF34D399); // emerald
    case NotificationKind.system:
      return const Color(0xFF60A5FA); // blue
    case NotificationKind.marketing:
      return const Color(0xFFF472B6); // pink
    case NotificationKind.kyc:
      return const Color(0xFFA78BFA); // purple
    case NotificationKind.goal:
      return const Color(0xFF2DD4BF); // teal
    case NotificationKind.other:
      return const Color(0xFFD4A13E); // gold
  }
}

IconData _iconForKind(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.security:
      return Icons.security_outlined;
    case NotificationKind.payment:
      return Icons.account_balance_wallet_outlined;
    case NotificationKind.system:
      return Icons.info_outline;
    case NotificationKind.marketing:
      return Icons.local_offer_outlined;
    case NotificationKind.kyc:
      return Icons.verified_user_outlined;
    case NotificationKind.goal:
      return Icons.flag_outlined;
    case NotificationKind.other:
      return Icons.notifications_outlined;
  }
}

class NotificationController extends ChangeNotifier {
  static const int _maxRealtimeEvents = 24;
  final List<NotificationItem> _items = [];
  final List<String> _realtimeEvents = [];
  bool _isLoading = false;
  String? _error;
  String? _authToken;
  final StreamController<Map<String, dynamic>> _balanceUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _enterpriseAlertController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _serviceAccessEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  final WebSocketService _ws = WebSocketService();
  StreamSubscription<dynamic>? _wsSubscription;
  bool _wsAuthed = false;
  String? _activeRealtimeToken;
  String? _activeRealtimeUserId;
  DateTime? _lastRealtimeStartedAt;
  DateTime? _lastRealtimeAuthedAt;
  DateTime? _lastRealtimeMessageAt;
  String? _lastRealtimeError;
  String? _lastRealtimeServerSessionId;
  String? _lastRealtimeServerSocketId;
  int _reconnectCycles = 0;

  final _fingerprint = DeviceFingerprint.generate();
  final _uuid = const Uuid();

  List<NotificationItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _items.where((n) => !n.isRead).length;
  bool get isRealtimeConnected => _ws.isConnected;
  bool get isRealtimeAuthed => _wsAuthed;
  DateTime? get lastRealtimeStartedAt => _lastRealtimeStartedAt;
  DateTime? get lastRealtimeAuthedAt => _lastRealtimeAuthedAt;
  DateTime? get lastRealtimeMessageAt => _lastRealtimeMessageAt;
  String? get lastRealtimeError => _lastRealtimeError;
  String? get realtimeClientTraceId => _ws.clientTraceId;
  int get realtimeConnectionSerial => _ws.connectionSerial;
  String? get lastRealtimeServerSessionId => _lastRealtimeServerSessionId;
  String? get lastRealtimeServerSocketId => _lastRealtimeServerSocketId;
  int get reconnectCycles => _reconnectCycles;
  List<String> get realtimeEvents => List.unmodifiable(_realtimeEvents);
  String get realtimeStatusLabel {
    if (_activeRealtimeToken == null || _activeRealtimeUserId == null) {
      return 'OFF';
    }
    if (_wsAuthed && _ws.isConnected) {
      return 'LIVE';
    }
    if (_ws.isConnected) {
      return 'AUTH';
    }
    if (_lastRealtimeError != null) {
      return 'RETRY';
    }
    return 'SYNC';
  }
  String get realtimeDebugSummary {
    final lastSeen = _lastRealtimeMessageAt?.toIso8601String() ?? 'none';
    final error = _lastRealtimeError ?? 'none';
    return 'status=$realtimeStatusLabel reconnects=$_reconnectCycles last=$lastSeen error=$error';
  }
  Stream<Map<String, dynamic>> get balanceUpdates =>
      _balanceUpdateController.stream;
  Stream<Map<String, dynamic>> get enterpriseAlerts =>
      _enterpriseAlertController.stream;
  Stream<Map<String, dynamic>> get serviceAccessEvents =>
      _serviceAccessEventController.stream;

  /// Fetch notifications from REST API.
  Future<void> fetch(String token, {int limit = 50, int offset = 0}) async {
    _isLoading = true;
    _error = null;
    _authToken = token;
    notifyListeners();

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/notifications',
      ).replace(queryParameters: {'limit': '$limit', 'offset': '$offset'});

      final res = await http.get(uri, headers: _headers(token));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        final data = body is Map<String, dynamic> ? body['data'] ?? body : body;
        final rawList = data is List
            ? data
            : data is Map
            ? (data['notifications'] ?? data['items'] ?? data['data'] ?? [])
            : <dynamic>[];

        final parsed = <NotificationItem>[];
        for (final element in rawList) {
          if (element is Map) {
            final map = Map<String, dynamic>.from(element);
            parsed.add(NotificationItem.fromJson(map));
          }
        }

        _items
          ..clear()
          ..addAll(parsed)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        _error = UserFacingError.from(
          Exception('status ${res.statusCode}'),
          fallback: 'Unable to load notifications right now.',
        );
      }
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to load notifications right now.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start realtime stream via WebSocket. Call immediately after login.
  void startRealtime(String token, String userId) {
    if (_activeRealtimeToken == token &&
        _activeRealtimeUserId == userId &&
        _ws.isConnected &&
        _wsSubscription != null) {
      return;
    }
    _authToken = token;
    _activeRealtimeToken = token;
    _activeRealtimeUserId = userId;
    _lastRealtimeStartedAt = DateTime.now();
    _lastRealtimeError = null;
    _lastRealtimeServerSessionId = null;
    _lastRealtimeServerSocketId = null;
    _wsSubscription?.cancel();
    _ws.disconnect();
    _wsAuthed = false;
    _ws.connect(AppConfig.wsUrl, token, userId: userId);
    _pushRealtimeEvent(
      'START user=$userId trace=${_ws.clientTraceId ?? 'pending'} serial=${_ws.connectionSerial}',
    );
    _wsSubscription = _ws.messages.listen(
      _handleWsMessage,
      onError: (error) {
        _wsAuthed = false;
        _reconnectCycles++;
        _lastRealtimeError = error.toString();
        _pushRealtimeEvent('ERROR ${error.toString()}');
        notifyListeners();
      },
      onDone: () {
        _wsAuthed = false;
        _reconnectCycles++;
        _lastRealtimeError = 'socket_closed';
        _pushRealtimeEvent('DONE socket_closed');
        notifyListeners();
      },
    );
    notifyListeners();
  }

  void stopRealtime() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _activeRealtimeToken = null;
    _activeRealtimeUserId = null;
    _ws.disconnect();
    _wsAuthed = false;
    _lastRealtimeError = null;
    _pushRealtimeEvent('STOP');
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx == -1) return;

    _items[idx] = _items[idx].copyWith(isRead: true);
    notifyListeners();

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/notifications/$id/read');
    try {
      await http.patch(uri, headers: _headers(_authToken));
    } catch (_) {
      // swallow network error; UI already updated
    }
  }

  Future<void> markAllAsRead() async {
    if (_items.isEmpty) return;
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isRead: true);
    }
    notifyListeners();

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/notifications/read-all');
    try {
      await http.patch(uri, headers: _headers(_authToken));
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    _items.removeWhere((n) => n.id == id);
    notifyListeners();

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/notifications/$id');
    try {
      await http.delete(uri, headers: _headers(_authToken));
    } catch (_) {}
  }

  Future<void> deleteMultiple(Iterable<String> ids) async {
    final idList = ids.toList();
    if (idList.isEmpty) return;

    final snapshot = List<NotificationItem>.from(_items);
    _items.removeWhere((n) => idList.contains(n.id));
    notifyListeners();

    try {
      await Future.wait(idList.map(_deleteRemote));
    } catch (e) {
      // rollback on failure
      _items
        ..clear()
        ..addAll(snapshot);
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to update notifications right now.',
      );
      notifyListeners();
    }
  }

  Future<void> deleteAll() async {
    await deleteMultiple(_items.map((n) => n.id));
  }

  // internal helpers ---------------------------------------------------

  Future<void> _deleteRemote(String id) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/notifications/$id');
    final res = await http.delete(uri, headers: _headers(_authToken));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        UserFacingError.from(
          Exception('status ${res.statusCode}'),
          fallback: 'Unable to delete notifications right now.',
        ),
      );
    }
  }

  Map<String, String> _headers(String? token) {
    final resolvedToken = token ?? _authToken;
    return OrbiRequestHeaders.build(
      token: resolvedToken,
      fingerprint: _fingerprint,
      trace: _uuid.v4(),
    );
  }

  void _handleWsMessage(dynamic message) {
    if (kDebugMode) {
      debugPrint('📡 WS_INCOMING | $message');
    }
    if (message is String) {
      final lower = message.trim().toLowerCase();
      if (lower == 'pong' || lower == 'ping') return;
      try {
        final data = jsonDecode(message);
        _handleParsedMessage(data);
      } catch (_) {
        _pushRealtimeEvent('MALFORMED_MESSAGE');
        // ignore malformed events
      }
      return;
    }

    if (message is Map) {
      _handleParsedMessage(message);
      return;
    }

    _pushRealtimeEvent('UNKNOWN_MESSAGE ${message.runtimeType}');
  }

  void _handleParsedMessage(Map<dynamic, dynamic> data) {
    final type = _eventType(data);
    if (type == 'PONG' || type == 'PING') return;
    _pushRealtimeEvent(type);

    if (type == 'AUTH_SUCCESS') {
      _wsAuthed = true;
      _lastRealtimeAuthedAt = DateTime.now();
      _lastRealtimeError = null;
      final payload = _payloadMap(data);
      _lastRealtimeServerSessionId =
          (payload['session_id'] ??
                  payload['sessionId'] ??
                  payload['ws_session_id'] ??
                  payload['websocket_session_id'])
              ?.toString();
      _lastRealtimeServerSocketId =
          (payload['socket_id'] ??
                  payload['socketId'] ??
                  payload['connection_id'] ??
                  payload['connectionId'])
              ?.toString();
      notifyListeners();
      return;
    }
    if (type == 'AUTH_FAILED' || type == 'AUTH_ERROR') {
      _wsAuthed = false;
      _lastRealtimeError = type;
      notifyListeners();
      return;
    }

    _lastRealtimeMessageAt = DateTime.now();
    _lastRealtimeError = null;

    if (type == 'NOTIFICATION') {
      final payload = _payloadMap(data);
      try {
        final item = NotificationItem.fromRealtime(
          Map<String, dynamic>.from(payload),
        );
        _upsert(item);
      } catch (_) {
        // ignore malformed event
      }
    }

    if (type == 'KYC_UPDATE') {
      final payload = _payloadMap(data);
      final status =
          payload['status']?.toString().trim().toUpperCase() ?? 'UPDATED';
      final level = payload['level']?.toString();
      final message = level == null || level.isEmpty
          ? 'Your KYC status changed to $status.'
          : 'Your KYC status is $status (Level $level).';
      final item = NotificationItem(
        id:
            (payload['id'] ??
                    payload['kyc_id'] ??
                    payload['requestId'] ??
                    _uuid.v4())
                .toString(),
        title: 'KYC Update',
        message: message,
        timestamp: DateTime.now(),
        isRead: false,
        category: 'KYC_UPDATE',
        kind: NotificationKind.kyc,
        color: _colorForKind(NotificationKind.kyc),
        icon: _iconForKind(NotificationKind.kyc),
      );
      _upsert(item);
    }

    _emitServiceAccessEventIfPresent(data);

    _emitEnterpriseAlertIfPresent(data);

    if (type == 'BALANCE_UPDATE' ||
        type == 'REFRESH_WALLETS' ||
        type == 'TRANSACTION_UPDATE') {
      _emitBalanceUpdate(data);
      return;
    }

    // Backward-compat fallback for older event names/payloads.
    if (_isBalanceAffectingEvent(data)) {
      _emitBalanceUpdate(data);
    }
  }

  bool _isBalanceAffectingEvent(Map<dynamic, dynamic> data) {
    final eventType = _toLower(data['type'] ?? data['event']);
    final payload = data['payload'] is Map
        ? Map<String, dynamic>.from(data['payload'] as Map)
        : <String, dynamic>{};
    final status = _toLower(
      payload['status'] ??
          payload['state'] ??
          payload['transaction_status'] ??
          data['status'],
    );
    final category = _toLower(payload['category'] ?? payload['kind']);
    final title = _toLower(payload['title'] ?? payload['subject']);
    final message = _toLower(payload['message'] ?? payload['body']);

    final hasFailureSignal =
        status.contains('fail') ||
        status.contains('declin') ||
        status.contains('reject') ||
        status.contains('cancel') ||
        status.contains('revers') ||
        status.contains('error') ||
        message.contains('failed') ||
        message.contains('reversed');
    if (hasFailureSignal) return false;

    final isBalanceType =
        eventType.contains('balance') ||
        eventType.contains('wallet') ||
        eventType.contains('transfer') ||
        eventType.contains('transaction') ||
        eventType.contains('deposit') ||
        eventType.contains('withdraw') ||
        eventType.contains('payment') ||
        eventType.contains('merchant') ||
        eventType.contains('agent');

    if (isBalanceType) {
      if (status.isEmpty) return true;
      return status.contains('success') ||
          status.contains('complete') ||
          status.contains('settl') ||
          status.contains('post') ||
          status.contains('done');
    }

    if (eventType == 'notification') {
      final text = '$category $title $message';
      return text.contains('balance') ||
          text.contains('wallet') ||
          text.contains('transfer') ||
          text.contains('deposit') ||
          text.contains('withdraw') ||
          text.contains('payment') ||
          text.contains('merchant') ||
          text.contains('agent');
    }

    return false;
  }

  void _emitBalanceUpdate(Map<dynamic, dynamic> data) {
    final payload = _payloadMap(data);
    final serverTimestamp =
        data['timestamp'] ??
        payload['timestamp'] ??
        DateTime.now().millisecondsSinceEpoch;
    final event = <String, dynamic>{
      'type': _eventType(data),
      'status': (payload['status'] ?? payload['state'] ?? '').toString(),
      'wallet_id':
          (payload['wallet_id'] ?? payload['walletId'] ?? payload['id'] ?? '')
              .toString(),
      'balance': _toDoubleOrNull(
        payload['balance'] ??
            payload['wallet_balance'] ??
            payload['current_balance'] ??
            payload['available_balance'],
      ),
      'timestamp': serverTimestamp,
      'raw': Map<String, dynamic>.from(
        data.map((key, value) => MapEntry(key.toString(), value)),
      ),
      'emitted_at': DateTime.now().toIso8601String(),
    };
    _balanceUpdateController.add(event);
  }

  void _emitEnterpriseAlertIfPresent(Map<dynamic, dynamic> data) {
    final type = _toLower(data['type'] ?? data['event']);
    final payload = data['payload'] is Map
        ? Map<String, dynamic>.from(data['payload'] as Map)
        : (data['data'] is Map
              ? Map<String, dynamic>.from(data['data'] as Map)
              : <String, dynamic>{});

    final combined = _toLower(
      payload['alert_type'] ??
          payload['type'] ??
          payload['category'] ??
          payload['code'] ??
          type,
    );

    if (!combined.contains('budget') &&
        !combined.contains('approval') &&
        !combined.contains('treasury')) {
      return;
    }

    final alert = <String, dynamic>{
      'id': payload['id'] ?? payload['alert_id'] ?? payload['request_id'],
      'alert_type': payload['alert_type'] ?? payload['type'] ?? combined,
      'message':
          payload['message'] ?? payload['body'] ?? payload['subject'] ?? '',
      'amount': payload['amount'],
      'currency': payload['currency'],
      'created_at':
          payload['created_at'] ??
          payload['timestamp'] ??
          DateTime.now().toIso8601String(),
      'category': payload['category'],
      'metadata': payload,
    }..removeWhere((_, value) => value == null || value == '');

    _enterpriseAlertController.add(alert);
  }

  void _emitServiceAccessEventIfPresent(Map<dynamic, dynamic> data) {
    final type = _toLower(data['type'] ?? data['event']);
    final payload = data['payload'] is Map
        ? Map<String, dynamic>.from(data['payload'] as Map)
        : (data['data'] is Map
              ? Map<String, dynamic>.from(data['data'] as Map)
              : <String, dynamic>{});

    final combined = _toLower(
      payload['category'] ??
          payload['type'] ??
          payload['alert_type'] ??
          payload['code'] ??
          type,
    );
    final message = _toLower(payload['message'] ?? payload['body'] ?? payload['subject']);

    final isServiceAccessEvent =
        combined.contains('service_access') ||
        combined.contains('merchant_access') ||
        combined.contains('agent_access') ||
        message.contains('merchant access') ||
        message.contains('agent access') ||
        message.contains('service access');

    if (!isServiceAccessEvent) return;

    final event = <String, dynamic>{
      'id': payload['id'] ?? payload['request_id'] ?? payload['notification_id'],
      'type': payload['type'] ?? combined,
      'status': payload['status'] ?? payload['decision'] ?? '',
      'requested_role': payload['requested_role'] ?? payload['role'] ?? '',
      'message': payload['message'] ?? payload['body'] ?? payload['subject'] ?? '',
      'timestamp': payload['timestamp'] ?? payload['created_at'] ?? DateTime.now().toIso8601String(),
      'metadata': payload,
    }..removeWhere((_, value) => value == null || value == '');

    _serviceAccessEventController.add(event);
  }

  String _eventType(Map<dynamic, dynamic> data) {
    return (data['type'] ?? data['event'] ?? '').toString().toUpperCase();
  }

  Map<String, dynamic> _payloadMap(Map<dynamic, dynamic> data) {
    if (data['payload'] is Map) {
      return Map<String, dynamic>.from(data['payload'] as Map);
    }
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  String _toLower(dynamic value) {
    if (value == null) return '';
    return value.toString().trim().toLowerCase();
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// Backward-compatible ingestion used by Dashboard's legacy WS hook.
  void ingestRealtime({
    required String type,
    required String title,
    required String message,
  }) {
    final kind = _kindFromCategoryOrType(type);
    final item = NotificationItem(
      id: _uuid.v4(),
      title: title.isNotEmpty ? title : 'Notification',
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
      category: type,
      kind: kind,
      color: _colorForKind(kind),
      icon: _iconForKind(kind),
    );
    _upsert(item);
  }

  void _upsert(NotificationItem item) {
    final idx = _items.indexWhere((n) => n.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.insert(0, item);
    }
    _items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  void _pushRealtimeEvent(String event) {
    final now = DateTime.now().toLocal();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    _realtimeEvents.insert(0, '$hh:$mm:$ss  $event');
    if (_realtimeEvents.length > _maxRealtimeEvents) {
      _realtimeEvents.removeRange(_maxRealtimeEvents, _realtimeEvents.length);
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _balanceUpdateController.close();
    _enterpriseAlertController.close();
    _serviceAccessEventController.close();
    _ws.dispose();
    super.dispose();
  }
}
