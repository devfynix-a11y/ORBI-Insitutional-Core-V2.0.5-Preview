import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/app_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<dynamic> _messageController =
      StreamController<dynamic>.broadcast();

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 20;
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(seconds: 25);
  static const Duration _staleConnectionThreshold = Duration(seconds: 75);
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  DateTime? _lastActivityAt;
  int _connectionSerial = 0;
  String? _clientTraceId;

  String? _baseUrl;
  String? _token;
  String? _userId;
  String? _lastConnectionErrorSignature;
  bool _isConnected = false;
  bool _isDisposed = false;
  bool _manualDisconnect = false;

  Stream<dynamic> get messages => _messageController.stream;
  bool get isConnected => _isConnected;
  int get connectionSerial => _connectionSerial;
  String? get clientTraceId => _clientTraceId;

  void connect(String baseUrl, String token, {String? userId}) {
    if (_isDisposed) return;
    _baseUrl = baseUrl;
    _token = token;
    _userId = userId;
    _reconnectAttempts = 0;
    _manualDisconnect = false;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _lastActivityAt = null;
    _connectionSerial++;
    _clientTraceId = _buildTraceId(_connectionSerial);
    unawaited(_establishConnection());
  }

  String _buildTraceId(int serial) {
    return 'ws-${DateTime.now().millisecondsSinceEpoch}-$serial';
  }

  Future<void> _establishConnection() async {
    final serial = _connectionSerial;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      if (_baseUrl == null) {
        throw Exception('baseUrl not set');
      }

      final candidates = _buildConnectionCandidates(_baseUrl!);
      Object? lastError;

      for (final uri in candidates) {
        final uriWithToken = uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            ...?(_token == null ? null : {'token': _token!}),
            ...?(_clientTraceId == null ? null : {'trace': _clientTraceId!}),
            ...?(_userId == null || _userId!.isEmpty ? null : {'userId': _userId!}),
          },
        );

        try {
          debugPrint('🔌 WebSocket connecting to: $uriWithToken');
          _channel = await _connectChannel(uriWithToken);
          _lastConnectionErrorSignature = null;
          _lastActivityAt = DateTime.now();

          _channel!.stream
              .handleError((Object e) {
                _onError(e, serial: serial);
              })
              .listen(
                (message) => _onMessage(message, serial: serial),
                onDone: () => _onDone(serial: serial),
                onError: (Object error) => _onError(error, serial: serial),
              );

          _isConnected = true;
          _reconnectAttempts = 0;
          if (_token != null && _token!.isNotEmpty) {
            _channel!.sink.add(
              jsonEncode({
                'event': 'AUTH',
                'type': 'AUTH',
                'token': _token,
                if (_userId != null && _userId!.isNotEmpty) 'userId': _userId,
                if (_clientTraceId != null) 'trace': _clientTraceId,
                'connectionSerial': _connectionSerial,
              }),
            );
          }
          _startHeartbeat();
          return;
        } catch (e) {
          lastError = e;
          _logConnectionFailure(uriWithToken, e);
        }
      }

      throw lastError ?? Exception('Unable to connect to any WebSocket endpoint');
    } catch (_) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  List<Uri> _buildConnectionCandidates(String baseUrl) {
    final normalizedBase = baseUrl.startsWith('ws')
        ? baseUrl
        : '${baseUrl.startsWith('https') ? 'wss' : 'ws'}://${baseUrl.replaceFirst(RegExp(r'^https?://'), '')}/nexus-stream';

    final primary = Uri.parse(normalizedBase);
    final candidates = <Uri>[primary];
    for (final fallback in AppConfig.wsUrls) {
      final fallbackUri = Uri.parse(fallback);
      if (fallbackUri != primary) {
        candidates.add(fallbackUri);
      }
    }

    if (primary.host.contains('c0re')) {
      candidates.add(primary.replace(host: primary.host.replaceAll('c0re', 'core')));
    } else if (primary.host.contains('core')) {
      candidates.add(primary.replace(host: primary.host.replaceAll('core', 'c0re')));
    }

    return candidates.toSet().toList(growable: false);
  }

  Future<WebSocketChannel> _connectChannel(Uri uri) async {
    if (kIsWeb) {
      return WebSocketChannel.connect(uri);
    }

    final socket = await WebSocket.connect(uri.toString()).timeout(
      const Duration(seconds: 15),
    );
    return IOWebSocketChannel(socket);
  }

  void _logConnectionFailure(Uri uri, Object error) {
    final signature = '${uri.host}|${error.runtimeType}|$error';
    if (_lastConnectionErrorSignature == signature) {
      return;
    }
    _lastConnectionErrorSignature = signature;
    debugPrint('❌ WebSocket connection error via ${uri.host}: $error');
  }

  void _onMessage(dynamic message, {required int serial}) {
    if (serial != _connectionSerial) return;
    _lastActivityAt = DateTime.now();
    _messageController.add(message);
  }

  void _onDone({required int serial}) {
    if (serial != _connectionSerial) return;
    _isConnected = false;
    _stopHeartbeat();
    _channel = null;
    if (_manualDisconnect || _isDisposed) return;
    _scheduleReconnect();
  }

  void _onError(Object error, {required int serial}) {
    if (serial != _connectionSerial) return;
    _isConnected = false;
    _stopHeartbeat();
    _channel = null;
    if (_manualDisconnect || _isDisposed) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _isDisposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;

    final exponentialMs =
        _initialReconnectDelay.inMilliseconds * (1 << _reconnectAttempts);
    final delayMs = exponentialMs > _maxReconnectDelay.inMilliseconds
        ? _maxReconnectDelay.inMilliseconds
        : exponentialMs;
    final delay = Duration(milliseconds: delayMs);
    _reconnectTimer = Timer(delay, () {
      if (_manualDisconnect || _isDisposed) return;
      _reconnectAttempts++;
      unawaited(_establishConnection());
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!_isConnected || _channel == null) {
        return;
      }

      final now = DateTime.now();
      if (_lastActivityAt != null &&
          now.difference(_lastActivityAt!) > _staleConnectionThreshold) {
        _isConnected = false;
        _channel?.sink.close();
        _channel = null;
        _stopHeartbeat();
        if (!_manualDisconnect && !_isDisposed) {
          _scheduleReconnect();
        }
        return;
      }

      try {
        _channel!.sink.add(
          jsonEncode({
            'event': 'PING',
            'timestamp': now.millisecondsSinceEpoch,
          }),
        );
      } catch (_) {
        _isConnected = false;
        _channel = null;
        _stopHeartbeat();
        if (!_manualDisconnect && !_isDisposed) {
          _scheduleReconnect();
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void disconnect() {
    _manualDisconnect = true;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _lastActivityAt = null;
  }

  void send(dynamic message) {
    if (!_isConnected || _channel == null) {
      throw StateError('WebSocket is not connected');
    }
    _channel!.sink.add(message);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _messageController.close();
  }
}
