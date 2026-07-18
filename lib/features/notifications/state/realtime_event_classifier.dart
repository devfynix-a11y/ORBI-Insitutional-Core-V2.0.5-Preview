enum RealtimeEventAudience { user, inboxOnly, auditOnly, silent }

enum RealtimeEventSource { core, talk, gateway, unknown }

class RealtimeNotificationCandidate {
  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime timestamp;
  final RealtimeEventSource source;
  final RealtimeEventAudience audience;
  final Map<String, dynamic> metadata;

  const RealtimeNotificationCandidate({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.timestamp,
    required this.source,
    required this.audience,
    required this.metadata,
  });

  bool get shouldStore => audience != RealtimeEventAudience.silent;
  bool get shouldPush => audience == RealtimeEventAudience.user;
}

class RealtimeEventClassifier {
  static RealtimeNotificationCandidate? classify(Map<dynamic, dynamic> data) {
    final type = _eventType(data);
    if (_isTransportEvent(type)) return null;

    final payload = _payloadMap(data);
    final token = _token(type, payload);
    final tokenLower = token.toLowerCase();
    final source = _source(type, payload);

    if (_isAuditOnly(type, payload) || _isInternalSecuritySignal(type, payload)) {
      return null;
    }

    final title = _pickString([
      payload['title'],
      payload['subject'],
      payload['heading'],
      _defaultTitle(tokenLower, source),
    ]);
    final message = _pickString([
      payload['message'],
      payload['body'],
      payload['description'],
      payload['text'],
      _defaultMessage(tokenLower, source),
    ]);

    if (title.isEmpty && message.isEmpty) return null;

    final timestamp = _timestamp(payload['timestamp'] ?? data['timestamp']);
    final id = _pickString([
      payload['id'],
      payload['notification_id'],
      payload['notificationId'],
      payload['message_id'],
      payload['messageId'],
      payload['event_id'],
      payload['eventId'],
      payload['transaction_id'],
      payload['transactionId'],
      payload['reference'],
      payload['ref'],
    ]);

    final category = _pickString([
      payload['category'],
      payload['template_name'],
      payload['event_code'],
      payload['type'],
      type,
    ]);

    return RealtimeNotificationCandidate(
      id: id.isEmpty
          ? 'rt_${timestamp.microsecondsSinceEpoch}_${tokenLower.hashCode.abs()}'
          : id,
      title: title.isEmpty ? 'ORBI' : title,
      message: message,
      category: category.isEmpty ? token : category,
      timestamp: timestamp,
      source: source,
      audience: _audience(tokenLower, payload),
      metadata: {
        ...payload,
        'realtime_source': source.name,
        'realtime_type': type,
      },
    );
  }

  static bool _isTransportEvent(String type) {
    return type == 'PONG' ||
        type == 'PING' ||
        type == 'AUTH' ||
        type == 'AUTH_SUCCESS' ||
        type == 'AUTH_FAILED' ||
        type == 'AUTH_ERROR';
  }

  static bool _isAuditOnly(String type, Map<String, dynamic> payload) {
    if (type == 'AUDIT_LOG') return true;
    final action = _pickString([
      payload['action'],
      payload['metadata'] is Map
          ? (payload['metadata'] as Map)['action']
          : null,
    ]).toUpperCase();
    return action.contains('API_GATEWAY_ALLOWED') ||
        action.contains('HEARTBEAT') ||
        action.contains('SOCKET');
  }

  static bool _isInternalSecuritySignal(
    String type,
    Map<String, dynamic> payload,
  ) {
    final metadata = payload['metadata'] is Map
        ? Map<String, dynamic>.from(payload['metadata'] as Map)
        : const <String, dynamic>{};
    final combined = [
      type,
      payload['type'],
      payload['category'],
      payload['event_code'],
      payload['action'],
      payload['title'],
      payload['subject'],
      payload['message'],
      payload['body'],
      metadata['type'],
      metadata['category'],
      metadata['event_code'],
      metadata['action'],
      metadata['title'],
      metadata['message'],
    ]
        .where((value) => value != null)
        .map((value) => value.toString().toLowerCase())
        .join(' ');
    return combined.contains('audit chain') ||
        combined.contains('integrity fail') ||
        combined.contains('integrity_violation') ||
        combined.contains('failrule') ||
        combined.contains('ledger_integrity') ||
        combined.contains('api_gateway_allowed');
  }

  static RealtimeEventAudience _audience(
    String token,
    Map<String, dynamic> payload,
  ) {
    final severity = _pickString([payload['severity'], payload['priority']])
        .toLowerCase();
    if (token.contains('audit')) return RealtimeEventAudience.auditOnly;
    if (token.contains('typing') || token.contains('heartbeat')) {
      return RealtimeEventAudience.silent;
    }
    if (severity.contains('silent') || severity.contains('low')) {
      return RealtimeEventAudience.inboxOnly;
    }
    return RealtimeEventAudience.user;
  }

  static RealtimeEventSource _source(String type, Map<String, dynamic> payload) {
    final combined = _pickString([
      payload['source'],
      payload['service'],
      payload['origin'],
      payload['category'],
      payload['template_name'],
      payload['event_code'],
      type,
    ]).toLowerCase();
    if (combined.contains('talk') || combined.contains('message')) {
      return RealtimeEventSource.talk;
    }
    if (combined.contains('gateway')) return RealtimeEventSource.gateway;
    if (combined.contains('core') ||
        combined.contains('transaction') ||
        combined.contains('payment') ||
        combined.contains('transfer') ||
        combined.contains('wealth') ||
        combined.contains('paysafe') ||
        combined.contains('escrow')) {
      return RealtimeEventSource.core;
    }
    return RealtimeEventSource.unknown;
  }

  static String _defaultTitle(String token, RealtimeEventSource source) {
    if (token.contains('transaction') || token.contains('transfer')) {
      return 'Transaction update';
    }
    if (token.contains('paysafe') || token.contains('escrow')) {
      return 'Orbi PaySafe update';
    }
    if (token.contains('shared_pot') || token.contains('pot')) {
      return 'Fungu update';
    }
    if (token.contains('shared_budget') || token.contains('budget')) {
      return 'Mezani update';
    }
    if (source == RealtimeEventSource.talk) return 'New message';
    return '';
  }

  static String _defaultMessage(String token, RealtimeEventSource source) {
    if (token.contains('transaction') || token.contains('transfer')) {
      return 'Your transaction has a new update.';
    }
    if (token.contains('paysafe') || token.contains('escrow')) {
      return 'Your PaySafe activity has a new update.';
    }
    if (token.contains('shared_pot') || token.contains('pot')) {
      return 'Your Fungu activity has a new update.';
    }
    if (token.contains('shared_budget') || token.contains('budget')) {
      return 'Your Mezani activity has a new update.';
    }
    if (source == RealtimeEventSource.talk) {
      return 'You have a new ORBI Talk message.';
    }
    return '';
  }

  static String _eventType(Map<dynamic, dynamic> data) {
    return (data['type'] ?? data['event'] ?? '').toString().toUpperCase();
  }

  static String _token(String type, Map<String, dynamic> payload) {
    return _pickString([
      payload['template_name'],
      payload['event_code'],
      payload['category'],
      payload['type'],
      type,
    ]);
  }

  static Map<String, dynamic> _payloadMap(Map<dynamic, dynamic> data) {
    if (data['payload'] is Map) {
      return Map<String, dynamic>.from(data['payload'] as Map);
    }
    if (data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  static DateTime _timestamp(dynamic raw) {
    if (raw is String) {
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw,
        isUtc: true,
      ).toLocal();
    }
    return DateTime.now();
  }

  static String _pickString(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }
}
